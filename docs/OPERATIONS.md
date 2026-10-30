# Deploy and operate AgriBridge

## Architecture and tradeoffs

Route 53 → ACM TLS on an AWS Network Load Balancer → F5 NGINX OSS Ingress
Controller → frontend Nginx → API.
The web bundle uses relative `/api` URLs. Nginx resolves the API service at runtime.
Only public HTTPS port 443 is exposed. The NLB decrypts TLS and forwards TCP to
NGINX's HTTP listener on port 80 through the Kubernetes NodePort. Public HTTP
port 80 is disabled. NLBs do not add `X-Forwarded-Proto`, so an HTTP redirect
based on that header would not distinguish the original connection correctly.
Kubernetes probes and metrics contact the API service
on its root paths, without rewriting. Operational endpoints are not public.

kOps generates the EC2/VPC/IAM Terraform in `terraform/modules/kops-cluster`,
called by the thin `terraform/cluster` entry point. One control
plane and two t3.medium workers span two availability zones. This is a cost-aware
assessment deployment, **not an HA control plane**. Each environment has its own
PostgreSQL StatefulSet and retained, encrypted gp3 volume; each database is a
single instance, so storage durability does not imply uninterrupted availability.
Redis is disposable and optional at runtime, but always provisioned. Production
and staging share the cluster, registry and monitoring; they have separate
namespaces, databases, signing secrets and deployment tokens.

No inbound SSH is permitted. Node bootstrap and add-ons are expressed in kOps and
Terraform. IMDSv2 is required with hop limit 1; workloads needing AWS use IRSA.
SSM is available for diagnostics; no host changes are needed to deploy.

The existing `kops` EC2 host is not needed: kOps runs from the operator workstation.
The stopped pre-existing instances are left untouched.

## First deployment and repeat application

Install AWS CLI, Terraform >=1.10, kOps 1.36.2, kubectl, Helm >=3.19, jq, Python 3 with
PyYAML, and GitHub CLI. Authenticate AWS and GitHub outside this repository.
Use Node 22.22.0 for builds and tests. Route 53 must have a public delegated zone
`agribridge.deuces.dev`; the existing zone is adopted into Terraform. In a new
account, delegate the nameservers Terraform creates at the parent DNS provider.
This unavoidable domain ownership step is the only external prerequisite.

```sh
bash scripts/provision.sh
# After committing changes to the configured GitHub repository:
gh workflow run delivery.yaml
```

For the existing cluster after a failed platform apply, run
`bash scripts/resume-platform.sh`. This resumes the service and platform state;
it does not recreate the cluster. The readiness gate waits for the AWS load
balancer, pod identity and EBS controllers and for ready admission service endpoints.
External Secrets gets a 15-minute cold-start timeout. Do not bypass a failing gate;
inspect the controller rollout and pod events first.

If an earlier failed External Secrets installation left its Helm release behind,
Terraform uses `upgrade_install = true` for that release. It upgrades the existing
`external-secrets/external-secrets` installation to the pinned 0.20.4 chart and
declared service-account role, or installs it when absent. This avoids the
`cannot re-use a name that is still in use` failure without uninstalling the
controller or deleting CRDs. Rerun `bash scripts/resume-platform.sh` after this
fix; only run delivery after the script reports the platform ready.

Ingress values live in the flat file `kops/nginx-ingress-values.yaml.tftpl`.
Terraform supplies the existing ACM certificate ARN and installs the maintained
F5 OSS chart `nginx-ingress` 2.8.0 (controller 5.7.0). The retired community
`ingress-nginx` chart is not used. The controller Service requests an internet-facing
NLB with instance targets, which works with this cluster's Calico networking.
The AWS Load Balancer Controller owns the NLB and its target groups; do not create
a second load balancer manually in the AWS console. Terraform waits for that Service's
load balancer hostname before writing the two Route 53 CNAME records.

The previous failed Traefik release changes to a new `nginx-ingress` Helm release
in the same namespace. Expect the ingress Helm resource replacement in the plan;
the application databases, secrets and cluster must not be replaced as part of it.

After applying the platform, verify the controller and Service:

```sh
export KUBECONFIG="$PWD/.runtime/kubeconfig"
kubectl -n ingress rollout status deployment/nginx-ingress-controller --timeout=300s
kubectl -n ingress get service nginx-ingress-controller
terraform -chdir=terraform/platform output app_urls
```

Run the delivery workflow to deploy the application, then check both HTTPS URLs.
A reachable controller can return 404 until the application Ingress is installed;
that alone does not prove the application is deployed. Keeping both environments
behind one NLB avoids creating a load balancer for each release.

The source folders were renamed from `web`, `charts`, and `infra` to `frontend`,
`helm`, and `terraform`; the cluster definition is now `kops/cluster.yaml`.
Terraform has four entry points (`bootstrap`, `cluster`, `services`, `platform`)
and resource modules under `terraform/modules`; see `terraform/README.md`.
Remote state keys stay `kops/terraform.tfstate`, `services/terraform.tfstate`, and
`platform/terraform.tfstate`. Explicit `moved` blocks map the previous resource
addresses into modules, preserving existing instances and secret values. Review the
first migration plan for unexpected replacements before applying. Use the scripts
to reinitialize each backend from its new path.

kOps configures workload tokens with audience `amazonaws.com`; the external-secrets,
logging and backup trust policies must use that same audience. GitHub Actions uses
its separate issuer and audience `sts.amazonaws.com`. The workload audience repair
was applied through AWS IAM on 30 October 2026 and is recorded in Terraform;
the next Terraform apply refreshes that state.

Edit `kops/cluster.yaml` for cluster settings; do not hand-edit generated
launch templates. The script regenerates Terraform and applies the documented
kOps service-webhook bootstrap fix before provisioning. It then waits for a healthy
cluster before installing platform charts. For existing nodes, changed instance
configuration requires a reviewed `kops rolling-update cluster --yes`; do not roll
all workers simultaneously because PostgreSQL and its EBS volume must reattach.

All application connections and secret identifiers flow from Terraform to SSM to
the delivery script. Only the pipeline role ARN is configured as a GitHub variable,
automatically. GitHub uses OIDC, not static AWS access keys. Deployments use
namespace-scoped Kubernetes tokens stored in Secrets Manager. These tokens are
long-lived: rotate them by replacing the corresponding `kubernetes_secret_v1.pipeline`
resource at `module.platform.kubernetes_secret_v1.pipeline` and reapplying
`terraform/platform`. Terraform state and these secrets are
operator-sensitive even though the role is limited to an application namespace.

Terraform service/cluster/platform state uses encrypted, versioned S3 and native
S3 lockfiles. Bootstrap state stays local and is copied to the same protected bucket
for recovery. Only one operator should change bootstrap at a time. Preserve state,
kOps state, and the OIDC discovery bucket when rebuilding. The discovery bucket
contains **public verification keys only**; the private kOps state bucket is blocked
from public access. Never upload `.runtime`, `.env`, tfstate, saved plans, or kubeconfigs.

## Local development

```sh
cp .env.example .env  # throwaway local values only
export GIT_SHA=$(git rev-parse HEAD)
export BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
docker compose up --build -d --wait
# http://localhost:8080 ; PostgreSQL on localhost:5433
```

The API and web Dockerfiles are identical across Compose and GitHub Actions.
`API_IMAGE`, `WEB_IMAGE` and `IMAGE_TAG` can select published images; use
`docker compose up --no-build` to run them. PostgreSQL survives `docker compose down`;
`down -v` deliberately deletes local data. Cookies are insecure only for local HTTP.

```sh
docker compose exec postgres createdb -U agribridge agribridge_test
PGPORT=5433 PGPASSWORD=local-development-only npm run test:integration --prefix api
npm run test:coverage --prefix api
npm run test:coverage --prefix frontend
```

Use the local password from `.env` when you change the example values. Never point
the integration tests at the application database.

## Release policy and identity

GitHub Actions runs strict `npm ci`, zero-warning lint, audits (high/critical fail),
API unit coverage gates, real PostgreSQL integration tests, web tests and coverage,
web build with a hard 250 KiB chunk limit, Helm lint, and Terraform formatting.
JUnit reports and coverage files are retained and failed test names are summarized.
The publish job builds both images once, exercises them with Compose, and publishes
unique release tags formed from commit SHA, run ID and attempt to Docker Hub:
`docker.io/macroni607/agribridge-api` and `docker.io/macroni607/agribridge-web`.
It reuses the existing `DOCKERHUB_TOKEN` repository secret and
`DOCKERHUB_USERNAME` variable from the earlier successful image-publishing workflow.
The token stays in GitHub Secrets and is passed only to the Docker login action.
Staging deploys first;
production receives the exact same tags without rebuilding. Helm uses atomic rollback
on failure. Neither production nor staging can release after a failed check.

The publish job does not require AWS credentials. Only the two deployment jobs use
AWS OIDC to read deployment parameters and namespace-scoped kubeconfigs. Terraform
configures the Docker Hub image references in SSM; provisioning also synchronizes
the namespace variable to GitHub. The two empty ECR repositories previously created
remain managed in the registry module to preserve existing resources; no pipeline
step publishes there, and the delivery role no longer needs ECR permissions.
Release tags are unique by convention; Docker Hub tag immutability has not been
configured or verified in this session.

`APP_VERSION`, `GIT_SHA`, `BUILD_DATE`, `IMAGE_TAG` are image identity only. Database,
cache, cookies and secret values are runtime configuration. Web identity is in OCI
labels; its JavaScript contains no environment-specific configuration.

The API acquires a PostgreSQL advisory lock for migrations, allowing replicas to
start safely. Use backward-compatible expand/contract schema migrations. Demo data
is seeded by a single Helm hook in staging, with its password resolved from Secrets
Manager. Production is deliberately unseeded; create real user accounts through a
controlled administrative process before opening it to users. There is no public
registration feature in the supplied application.

Staging accounts: `amina.yusuf@example.ng` (farmer),
`procurement@sahelmills.example` (buyer). Authorized operators can retrieve
`SEED_PASSWORD` from `agribridge-staging/runtime` in Secrets Manager. It is never
embedded in the login page, printed by the seed command, or committed to Git.

## Health, logs, and metrics

```sh
export KUBECONFIG="$PWD/.runtime/kubeconfig"
kubectl -n agribridge-staging get pods,externalsecrets,pvc
kubectl -n agribridge-staging exec deploy/agribridge-api -- node -e \
  "fetch('http://localhost:3000/readyz').then(r=>r.json()).then(console.log)"
kubectl -n monitoring port-forward svc/monitoring-grafana 3001:80
# Grafana at http://localhost:3001 (admin password is in the monitoring-grafana Secret).
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
aws logs tail /agribridge/containers --region us-east-1 --since 10m
```

`/healthz` checks the process, not PostgreSQL; using the DB for liveness would restart
healthy processes during a dependency outage. `/readyz` removes pods from routing
when PostgreSQL is unavailable; Redis loss returns HTTP 200 with `degraded: true`.
Startup allows 300 seconds. Termination allows 30 seconds: five seconds to drain
routing followed by the API's ten-second shutdown bound. A disconnected Redis
client cannot hold startup forever or queue cache commands indefinitely.

Prometheus scrapes `/metrics`. Useful expressions:

- Requests: `sum(rate(http_requests_total[5m]))`
- p95: `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))`
- Pool pressure: `db_pool_connections{state="waiting"}`
- Cache errors: `sum(rate(cache_operations_total{result="error"}[5m]))`
- Release identity: `agribridge_build_info`

Prometheus and Grafana use EBS persistence. CloudWatch retains container logs 14 days.
Alerts are visible in Prometheus/Alertmanager; external notification delivery is not
configured without an agreed recipient. Restrict operator access; dashboards are not
exposed publicly.

## Rollback

```sh
kubectl -n agribridge-staging get deploy
helm history agribridge -n agribridge-staging
helm rollback agribridge PREVIOUS_REVISION -n agribridge-staging --wait --timeout 10m
```

Repeat for production only when needed. Verify `/version` from the API pod, readiness,
and login after rollback. Database migrations are not automatically reversed; restore
only when a data/schema recovery is necessary, following the next section.

## Backup and restore

Each namespace has a daily PostgreSQL `pg_dump -Fc` CronJob. Dumps are uploaded to a
private encrypted S3 bucket under separate environment prefixes, retained 30 days
with versioning. Daily backups imply up to 24 hours of data loss; choose a tighter
schedule or PostgreSQL WAL archiving if a smaller RPO is required.

```sh
kubectl -n agribridge-staging create job --from=cronjob/agribridge-backup backup-manual-$(date +%s)
# Run the isolated restore drill described by scripts/restore-drill.sh:
bash scripts/restore-drill.sh staging S3_OBJECT_KEY
```

A restore drill never overwrites the live `agribridge` database. It downloads one S3
backup, restores to an isolated temporary PostgreSQL pod, checks row counts and schema,
and removes the drill resources on exit. Preserve successful backup/restore evidence.
For an actual disaster, stop API writers, restore a validated backup into replacement
storage/database, verify counts and application flows, then switch the API connection
and restart it. Keep the damaged volume until the recovery is accepted. Do not treat
a successful upload as proof that restoration works.

## Cost and teardown

Charges continue while the three EC2 instances, load balancer, EBS volumes, S3,
Secrets Manager and CloudWatch remain provisioned. There is no EKS fee or NAT gateway.
T3 instances may incur surplus CPU-credit charges under sustained load. Cost depends
on usage; check AWS Billing before leaving a demonstration running unattended.

Destroy application releases first, then `terraform/platform` (so the load balancer
controller is still available), then services and the kOps-generated Terraform.
Retained PostgreSQL/Grafana/Prometheus EBS volumes and backup/state buckets are
intentionally not deleted automatically. Inventory and explicitly dispose of them only
after exporting data and agreeing on retention. The hosted zone and state buckets have
Terraform `prevent_destroy` protection. Never delete them merely to silence a plan.
