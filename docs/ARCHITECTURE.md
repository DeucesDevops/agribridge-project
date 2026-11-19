# Architecture

![AgriBridge architecture](images/agribridge-architecture.jpg)

The request path in the diagram is current. The cluster is Amazon EKS, created by Terraform.

## Application

The web app is React and Vite, served by NGINX. It proxies `/api` to the
Express API. PostgreSQL stores marketplace data. Redis caches responses. If
Redis is unreachable, the API reads PostgreSQL and reports the degradation on
`/readyz`. The API also exposes `/healthz`, `/metrics`, and `/version`.

Docker Compose runs those four processes for local development. The same
processes run in Kubernetes from one chart, `helm/agribridge`.

| File | Namespace | Host | Demo data |
|---|---|---|---|
| `values-qa.yaml` | `agribridge-qa` | `qa.<zone>` | Loaded on startup |
| `values-production.yaml` | `agribridge-production` | `production.<zone>` | Not loaded |

Both releases use one image tag. Each namespace has its own database volume
and its own Secrets Manager secret.

## Pipeline

The file is [`.github/workflows/cicd.yaml`](../.github/workflows/cicd.yaml).
SonarQube runs on `main` when `SONAR_TOKEN` and `SONAR_HOST_URL` are set, and
the job succeeds with a skip message otherwise. A push to `main` publishes
`docker.io/macroni607/agribridge-api` and
`docker.io/macroni607/agribridge-web`, then runs `helm upgrade` in
`agribridge-qa`. The `production` GitHub environment must approve the same tag
before the production install. Pull requests and `dev` finish after the image
scan and SBOM.

## Cluster and AWS

Terraform creates the cluster. It is Amazon EKS 1.36 in a VPC with two public
subnets. The managed node group is `t3.large`, the root disks are encrypted,
and the launch template has no SSH key. The API is public. Callers need an
EKS access entry. The person who applies Terraform is an admin, and so is the
GitHub Actions role.

EKS is in this root because the cluster, the zone, the certificate and the
roles then come from one apply. A kOps cluster would keep a second state
store and a second command. The kOps Terraform target writes a generated tree
that has to be regenerated with kOps, so the source of the cluster would still
be kOps.

The same root also creates:

- the public Route 53 zone and the ACM certificate for the zone and `*.zone`
- the GitHub Actions OIDC role, and it writes that role ARN to GitHub
- Secrets Manager secrets `agribridge/qa`, `agribridge/production` and `agribridge/grafana`
- IRSA roles for External Secrets, ExternalDNS, the load balancer controller, the EBS CSI driver and the backup jobs
- the backup bucket
- the platform Helm releases, on a second apply, once the API exists

The state bucket is the exception. `scripts/bootstrap-state.sh` creates it,
because Terraform needs it before the first `init`.

## Traffic and secrets

Route 53 names `qa.<zone>` and `production.<zone>` point at one ALB. The
Ingress in the Helm chart asks the load balancer controller for that ALB and
attaches the ACM certificate. ExternalDNS creates the records from the Ingress
host.

External Secrets reads Secrets Manager with an IAM role. The trust policy uses
the EKS OIDC issuer and the audience `sts.amazonaws.com`. The synced secret
supplies `PGPASSWORD`, `JWT_SECRET`, and `SEED_PASSWORD`.

Production PostgreSQL is backed up by a CronJob in the application chart. It
runs `pg_dump` and uploads the file to S3 with its own IRSA role. Restore is
`scripts/restore-postgres.sh`. QA uses the same switch and leaves it off.

## Observability

Prometheus scrapes `/metrics` through a ServiceMonitor. Promtail ships
container logs to Loki. Grafana is configured with Prometheus, Loki, and Tempo
datasources. The API does not export traces, so Tempo has no application spans
until a tracer is added. Grafana is served at `https://grafana.<zone>` on the
same load balancer. Anonymous access is off. The admin password is in Secrets
Manager.

## What this repository does not contain

Argo CD, an NGINX ingress controller, a Network Load Balancer, Fluent Bit,
CloudWatch Logs, composite GitHub Actions, and extra Terraform roots are not
part of this design. The environment name is QA.
