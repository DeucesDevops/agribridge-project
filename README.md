# AgriBridge

AgriBridge is a grain marketplace. Farmers publish produce, buyers place orders,
and both can follow an order through fulfilment. The web app is React and Vite.
The API is Express, with PostgreSQL and Redis.

Local development uses Docker Compose. The cloud environment is a kOps cluster
on AWS. GitHub Actions builds the images, a reviewer approves production, and
Argo CD syncs that commit.

## Features

- **Farmer workspace:** publish crop lots with quantity, price and location.
- **Buyer workspace:** browse available produce and place orders.
- **Order management:** track status changes and order history.
- **Dashboard:** view marketplace activity and credit eligibility.
- **Role-based access:** separate farmer and buyer experiences with cookie-based authentication.

## Architecture

![AgriBridge architecture](docs/images/agribridge-architecture.svg)

The diagram is the delivery path. kOps renders the cluster into Terraform, and Terraform creates it.

A browser opens [https://production.agribridge.deuces.dev](https://production.agribridge.deuces.dev).
Route 53 sends that name to one internet-facing Application Load Balancer.
TLS is the ACM certificate for `agribridge.deuces.dev` and `*.agribridge.deuces.dev`.
Calico pod IPs are not routable from the VPC, so the load balancer uses
instance targets and the web Service is a NodePort. NGINX in the web pod
serves the React app.

The API serves `/healthz`, `/readyz`, `/version`, and `/metrics` at the root,
not under `/api`. NGINX on the public hostname routes them like this.

| Public path | Who answers |
|---|---|
| `/` | React app |
| `/api/` | Proxied to Express. The `/api` prefix is kept |
| `/healthz` | NGINX itself, body `ok`. This is the load balancer health check |
| `/readyz` | Proxied to the API. Redis down is reported here and PostgreSQL is still read |
| `/version` | Proxied to the API |
| `/metrics` | Not proxied. Prometheus scrapes the API Service inside the cluster |

Express stores data in PostgreSQL and caches in Redis. Sign-in uses the seeded
accounts. The API has login, logout, and session lookup, and it does not
register new users.

Locally, Docker Compose runs the same four processes and loads the demo data.
In AWS they run from one Helm chart, `helm/agribridge`, with `values.yaml` and
`values-production.yaml`, in the namespace `agribridge-production`.
Production sets `SEED_DEMO_DATA=false`. The accounts were loaded once with
`node`, because the image has no npm. The command is in [docs/SETUP.md](docs/SETUP.md).

The workflow file is [`.github/workflows/cicd.yaml`](.github/workflows/cicd.yaml).
SonarQube runs on `main` only when `SONAR_TOKEN` and `SONAR_HOST_URL` are set.
On `main`, the images are pushed to `docker.io/macroni607/agribridge-api` and
`docker.io/macroni607/agribridge-web`. Production waits for the `production`
GitHub environment. After approval, the workflow commits that image tag into
`values-production.yaml` on `main`. The commit message contains `[skip ci]`
and the author is DeucesDevops. Argo CD tracks `main` and syncs the chart.
Pull requests and pushes to `dev` stop after the scans. They do not push images
or change the production tag.

kOps renders the cluster from [`kops/cluster.yaml`](kops/cluster.yaml) into
Terraform with `kops update cluster --target=terraform`, and `terraform apply`
creates it: the VPC, one `t3.medium` control plane, two `t3.large` workers,
the EBS CSI driver, the AWS Load Balancer Controller, and the service-account
issuer. The same root creates the public DNS zone, the certificate, the Secrets
Manager secrets, the backup bucket, the GitHub Actions variables and
`production` environment, and the IRSA roles for External Secrets, ExternalDNS
and the database backup. A second apply, with `install_platform=true`, installs
External Secrets, ExternalDNS, Argo CD, kube-prometheus-stack, Loki, and Promtail.
External Secrets copies `PGPASSWORD`, `JWT_SECRET`, and `SEED_PASSWORD` into
the production namespace. The role trust uses the kOps issuer and the audience
`amazonaws.com`. Production runs a daily `pg_dump` to S3 at 02:15 UTC. Objects
expire after 30 days.

Grafana is [https://grafana.agribridge.deuces.dev](https://grafana.agribridge.deuces.dev)
on that same load balancer. Its Service is a NodePort, the Ingress target type
is `instance`, and the load balancer group is `agribridge`. Sign in with the
`admin_user` and `admin_password` keys in Secrets Manager `agribridge/grafana`.
Anonymous access and sign-up are off. Prometheus stays inside the cluster. Use
it from Grafana Explore, or open its own UI with
`kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090`.

Argo CD is [https://argocd.agribridge.deuces.dev](https://argocd.agribridge.deuces.dev)
on that same load balancer. Its Service is a NodePort, the Ingress target type
is `instance`, and the load balancer group is `agribridge`. TLS ends at the
load balancer. The username is `admin`. Argo CD generates the password into
the secret `argocd-initial-admin-secret`. Read it on your machine:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

The same command is `terraform output argocd_admin_password_command`. Do not
paste the password into git, issues, or chat. The Application `agribridge`
tracks `main` at `helm/agribridge`, with automated sync, prune and selfHeal.

Prometheus scrapes the API at `/metrics`. Promtail ships container logs to Loki.
Grafana reads Prometheus and Loki. Distributed tracing is a later addition:
OpenTelemetry in the API, plus Tempo. Neither is installed.

| Layer | Where it lives |
|---|---|
| Frontend | React and Vite, served by NGINX |
| API | Express on Node.js |
| Data | PostgreSQL and Redis in `agribridge-production` |
| Local | Docker Compose |
| Chart | `helm/agribridge` with `values-production.yaml`, synced by Argo CD |
| Cluster | kOps `k8s.agribridge.deuces.dev`, rendered to Terraform in `terraform/kops` |
| AWS around the cluster | `terraform/`: zone, certificate, secrets, backup bucket, GitHub, IRSA, platform charts |
| Images | Docker Hub `macroni607/agribridge-api` and `macroni607/agribridge-web` |
| Delivery | Approved commit of the image tag on `main`, then Argo CD |
| Traffic | Route 53 and ACM to one ALB, then the web, Grafana and Argo CD NodePorts |
| Secrets | Secrets Manager through External Secrets. Argo CD's admin password is a cluster secret |
| Observability | Prometheus, Grafana, Loki, Promtail |

The repository does not include an NGINX ingress or a Network Load
Balancer, Fluent Bit or CloudWatch logs, composite actions, or separate
Terraform roots. Build the cloud environment in the order in
[docs/SETUP.md](docs/SETUP.md). The longer explanation is
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Quick start

Install Docker with Docker Compose v2, then run:

```sh
git clone https://github.com/DeucesDevops/agribridge-project.git
cd agribridge-project
cp .env.example .env
docker compose up --build -d --wait
```

Open [http://localhost:8080](http://localhost:8080).

Compose builds the web app and the API, starts PostgreSQL and Redis, and loads
demonstration data. Copy `.env.example` to `.env` and change the passwords
before you start.

### Demo accounts

| Role | Email |
|---|---|
| Farmer | `amina.yusuf@example.ng` |
| Buyer | `procurement@sahelmills.example` |
| Agent | `agent@agribridge.example` |

Locally the password is `SEED_PASSWORD` in `.env`. Compose sets
`SEED_DEMO_DATA=true` and loads these accounts on startup, plus additional
farmers, buyers, lots, and orders. Production leaves `SEED_DEMO_DATA` off.
The production password is the `SEED_PASSWORD` key in Secrets Manager
`agribridge/production`. Read that key when you sign in. Do not paste it into
git, issues, or chat.

### Useful commands

```sh
docker compose ps
docker compose logs -f api
docker compose down
```

The web port defaults to `8080`. Set `WEB_LOCAL_PORT` in `.env` to change it.
Local PostgreSQL is published on `5433` unless `PG_LOCAL_PORT` is set.

## Development and testing

Use Node.js 22.

```sh
npm ci --prefix api
npm ci --prefix frontend
npm run test:coverage --prefix api
npm run test:coverage --prefix frontend
npm run build --prefix frontend
```

`make check` lints the Helm chart, checks Terraform formatting and runs the
SonarQube coverage helper tests. It needs Helm, Terraform and Python 3.

## Cloud delivery

GitHub Actions lints and tests the app, scans for secrets and vulnerabilities,
builds both images, writes a SBOM, and pushes them to Docker Hub. Production
waits for a reviewer on the `production` environment, then commits that image
tag. Argo CD installs it.

kOps renders the cluster and Terraform creates it, the zone, the certificate,
the IAM roles and the platform charts. `scripts/bootstrap-state.sh` creates
the Terraform state bucket, which Terraform needs before it can start. The
kOps state bucket is separate and is managed by Terraform. Images are
published to Docker Hub. The exact commands are in [docs/SETUP.md](docs/SETUP.md).

| Guide | Contents |
|---|---|
| [Setup](docs/SETUP.md) | Stage-by-stage build, from an empty AWS account to production |
| [Pipeline](docs/PIPELINE.md) | Each job, and the GitHub settings it needs |
| [Architecture](docs/ARCHITECTURE.md) | What runs where |
| [SonarQube](sonarqube/README.md) | Optional local code-quality server |

## Repository layout

| Directory | Purpose |
|---|---|
| `frontend/`, `api/` | Application source and tests |
| `.github/workflows/cicd.yaml` | The only delivery workflow |
| `kops/` | kOps cluster spec |
| `terraform/` | Rendered kOps cluster, DNS, secrets, backup bucket, IAM, platform charts |
| `helm/agribridge/` | Application chart, including the production backup |
| `helm/agribridge-application/` | Argo CD Application for that chart |
| `platform/` | Storage class and observability Helm values |
| `scripts/` | State bucket, apply, restore and teardown |
| `sonarqube/` | Optional local SonarQube |
| `docs/` | Setup, pipeline and architecture |
