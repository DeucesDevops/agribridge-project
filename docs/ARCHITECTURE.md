# Architecture

AgriBridge is four processes. The browser talks to the web app. The web app calls the API. The API reads and writes PostgreSQL and optionally caches in Redis.

```text
browser
  |
  |  http://localhost:8080  (Compose) or http://localhost:5173 (Vite)
  v
web (NGINX or Vite)
  |
  |  /api, /readyz, /version
  v
API (Express :3000)
  |                 \
  |                  \  optional
  v                   v
PostgreSQL           Redis
```

Locally, Docker Compose runs all four. Without Compose, run PostgreSQL, Redis, `npm run dev` in `api/` and `npm run dev` in `frontend/`. Vite then serves the React app and proxies `/api`.

## Web

The UI is a single React page with four views: dashboard, the farmer's lots, the buyer's open lots, and orders. Which tabs appear depends on the signed-in role. Farmer and agent see produce. Buyer and agent see open lots. There is no client-side router; view state stays in the root component so the bundle stays small.

NGINX in `frontend/nginx.conf.template` routes the container port `8080` as follows.

| Path | Who answers |
|---|---|
| `/` and `/assets/` | The built React app |
| `/api/` | Proxied to the API. The prefix is unchanged |
| `/healthz` | NGINX returns `ok` |
| `/readyz` | Proxied to the API `/readyz` |
| `/version` | Proxied to the API `/version` |

`/metrics` is not proxied by NGINX. Scrape it on the API port.

## API

Application routes live under `/api`. Operational routes live at the root so probes do not depend on the `/api` prefix.

| Method and path | Purpose |
|---|---|
| `POST /api/auth/login` | Session cookie |
| `POST /api/auth/logout` | Clear the session |
| `GET /api/auth/me` | Current user |
| `/api/lots` | Publish and browse produce |
| `/api/orders` | Place orders and change status |
| `POST /api/orders/credit-check` | Farmer input-credit eligibility |
| `GET /api/stats/summary` | Dashboard totals |
| `GET /api/stats/by-crop` | Orders grouped by crop |
| `GET /api/stats/funnel` | Order counts by status |
| `GET /healthz` | Process is alive. Does not touch PostgreSQL or Redis |
| `GET /readyz` | PostgreSQL is reachable. Redis down is degradation unless `REDIS_REQUIRED=true` |
| `GET /version` | Build identity from `APP_VERSION`, `GIT_SHA`, `BUILD_DATE` and `IMAGE_TAG` |
| `GET /metrics` | Process and business metrics in Prometheus text format |

Authentication is a signed JWT in an httpOnly cookie. The API does not create users except through the demo seed.

Pricing is a pure function in `api/src/domain/pricing.js`. Grade A keeps the asking price, grade B multiplies by 0.93 and grade C by 0.85. The platform fee is 2.5% of the graded total and is taken from the farmer payout. Order tonnage must be between 0.5 and 5000.

Credit eligibility is a pure function in `api/src/domain/credit.js`. A farmer can request an advance of up to 40% of settled order value from the trailing 365 days, capped at 2,000,000 naira, and only after at least one qualifying settled order.

On shutdown the API stops accepting connections, waits up to `SHUTDOWN_GRACE_MS` for in-flight requests, then closes PostgreSQL and Redis.

## Data

`api/src/migrations/001_init.sql` creates the schema. `api/src/migrate.js` applies it under a Postgres advisory lock so several API processes can start together.

| Table | Contents |
|---|---|
| `users` | Farmer, buyer and agent accounts |
| `lots` | Produce offered for sale: crop, tonnage, grade, state, price, status |
| `orders` | A buyer's purchase of part of a lot, including fee and payout |
| `order_events` | Append-only status changes, with the actor and request id |

Lot status is `OPEN`, `RESERVED`, `SOLD` or `WITHDRAWN`. Order status is `PENDING`, `MATCHED`, `IN_TRANSIT`, `DELIVERED`, `SETTLED` or `CANCELLED`.

`api/src/seed.js` inserts demo farmers, buyers, an agent, lots and orders when `SEED_DEMO_DATA` is true and `users` is empty. It requires `SEED_PASSWORD`.

Redis caches dashboard aggregates. A cache miss or a Redis outage falls back to PostgreSQL. Query labels and metric labels stay low-cardinality: they use a logical operation name or the route template, never an order id or user id.

Logs are one JSON object per line on stdout, with a `request_id` that matches the `X-Request-Id` response header and the `request_id` stored on `order_events`.

## Production

![AgriBridge architecture](images/agribridge-architecture.svg)

The diagram is the delivery path. The cluster is kOps, and Terraform creates the machines from the rendered spec. [ADR 0001](ADR/0001-kops.md) records why.

The same four processes run in Kubernetes from one chart, `helm/agribridge`. Production uses `values-production.yaml`: namespace `agribridge-production`, host `production.agribridge.deuces.dev`, and `SEED_DEMO_DATA=false`. The release uses the image tag committed in that file on `main`. The namespace has its own database volume and the Secrets Manager secret `agribridge/production`.

NGINX is what the load balancer calls. `/healthz` is the ALB health check. Prometheus scrapes `/metrics` on the API Service through a ServiceMonitor. The probes talk to the API container, not to NGINX.

## Pipeline

[`.github/workflows/ci.yaml`](../.github/workflows/ci.yaml) runs lint and test, then security, Terraform, the image build, and the production tag commit. SonarQube runs on `main` when `SONAR_TOKEN` and `SONAR_HOST_URL` are set, and the job succeeds with a skip message otherwise. A push to `main` publishes `docker.io/macroni607/agribridge-api` and `docker.io/macroni607/agribridge-web`. The `production` GitHub environment must approve that tag before the workflow commits it to `values-production.yaml`. The commit author is DeucesDevops and the message contains `[skip ci]`, so the bump does not build again. Argo CD tracks `main` and syncs `helm/agribridge` with prune and selfHeal. Pull requests and `dev` finish after the image scan and SBOM.

## Cluster and AWS

The cluster spec is [`kops/cluster.yaml`](../kops/cluster.yaml). kOps 1.36.2 renders it with `kops update cluster --target=terraform` into [`terraform/modules/cluster`](../terraform/modules/cluster) and [`terraform/modules/network`](../terraform/modules/network). Terraform creates what those files describe: the VPC, one `t3.medium` control plane, two `t3.large` workers, encrypted root disks, no SSH key, the API on port 443, Calico, the EBS CSI driver, the AWS Load Balancer Controller, and the service-account issuer. The issuer is `https://agribridge-oidc-237258628535.s3.us-east-1.amazonaws.com` and the token audience is `amazonaws.com`.

Rendering also writes the cluster certificates into `s3://kops-state-607`. The node configuration Terraform uploads has to match those certificates, so `scripts/render-kops-terraform.sh` runs before apply. The GitHub Actions role can still read the state bucket and export a kubeconfig with `kops export kubeconfig --admin`. The pipeline does not use that credential. The image-tag job only pushes a commit.

`scripts/bootstrap-state.sh` creates the Terraform state bucket before the first production `init`. Environment backends set `use_lockfile = true`.

The production root also creates:

- the public Route 53 zone `agribridge.deuces.dev` and the ACM certificate for that name and `*.agribridge.deuces.dev`
- the GitHub Actions OIDC role, and it writes that role ARN to GitHub
- Secrets Manager secrets `agribridge/production` and `agribridge/grafana`
- IRSA roles for External Secrets, ExternalDNS, and the database backup. The load balancer controller and the EBS driver roles are in the kOps output
- the kOps state bucket, the OIDC discovery bucket, and the backup bucket
- the platform Helm releases, on a second apply with `install_platform=true`: Argo CD, external-secrets, external-dns, kube-prometheus-stack, Loki, and Promtail

## Traffic and secrets

The Route 53 name `production.agribridge.deuces.dev` points at the ALB. The Ingress joins the load balancer group `agribridge`, sets `target-type` to `instance`, and attaches the ACM certificate. The web Service is a NodePort because Calico pod IPs are not routable from the VPC. ExternalDNS creates the records from the Ingress host. Grafana (`grafana.agribridge.deuces.dev`) and Argo CD (`argocd.agribridge.deuces.dev`) use the same group and instance targets.

External Secrets reads Secrets Manager with an IAM role. The trust policy uses the kOps issuer and the audience `amazonaws.com`. The synced secret supplies `PGPASSWORD`, `JWT_SECRET`, and `SEED_PASSWORD`. Read them on your machine:

```sh
aws secretsmanager get-secret-value --secret-id agribridge/production --query SecretString --output text
```

Grafana's username and password are the `admin_user` and `admin_password` keys in `agribridge/grafana`:

```sh
aws secretsmanager get-secret-value --secret-id agribridge/grafana --query SecretString --output text
```

The Argo CD username is `admin`. The generated password is in `argocd-initial-admin-secret`:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

Production PostgreSQL is backed up by a CronJob in the application chart. It runs `pg_dump` and uploads the file to S3 with its own IRSA role. Restore is `scripts/restore-postgres.sh`. See [RUNBOOKS/backup-restore.md](RUNBOOKS/backup-restore.md).

## Observability

Prometheus scrapes `/metrics` through a ServiceMonitor. Promtail ships container logs to Loki. Grafana's datasources are Prometheus and Loki. Anonymous access and sign-up are off. Values for those releases are in `platform/monitoring-values.yaml`.

The API objectives are in [observability/slos/api.yaml](../observability/slos/api.yaml): 99.5% of requests are not 5xx, and p95 latency stays under 400ms. [observability/alerts/api.yaml](../observability/alerts/api.yaml) pages when a 10 minute window breaks either objective. The platform module loads those alerts and [observability/dashboards/api.json](../observability/dashboards/api.json) into the monitoring release.

Prometheus has no Ingress. Query it from Grafana, or from a machine that has a kubeconfig:

```sh
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090
```

The Application `agribridge` lives in the `argocd` namespace. It points at `https://github.com/DeucesDevops/agribridge-project.git`, revision `main`, path `helm/agribridge`, and value files `values.yaml` and `values-production.yaml`. The repository is public, so Argo CD clones it without a credential. Automated sync is on, with prune and selfHeal. Terraform sets the Helm parameters `hostname`, `region`, `certificateArn`, `backup.bucket`, and `backup.roleArn` on that Application. Image tags come from the committed values file. Argo CD reconciles git about every 60 seconds. Refresh sooner with:

```sh
kubectl -n argocd annotate application agribridge argocd.argoproj.io/refresh=hard --overwrite
```

