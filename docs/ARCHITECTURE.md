# Architecture

AgriBridge contains two independently built components: a React frontend served
by Nginx and an Express API. PostgreSQL stores marketplace data; Redis caches
aggregates. The frontend uses relative `/api` requests, so one image can be
promoted unchanged between environments.

## Ownership

| Owner | Resources |
|---|---|
| Terraform | AWS networking/compute through kOps-generated Terraform, DNS/TLS, runtime secrets, workload IAM, backups/logging resources, namespaces, storage and platform Helm releases |
| Argo CD | Application Deployments, Services, PostgreSQL StatefulSet/PVC templates, Redis, ingress, runtime secret references, monitoring rules and backup CronJobs from `helm/agribridge` |
| GitHub delivery workflow | Tests, immutable image publication, GitOps release selections and acceptance gates |
| GitHub infrastructure workflow | Ordered Terraform plans/applies with remote state locking |
| GitHub operations workflow | Explicit maintenance jobs and acceptance checks |

Terraform's small Argo CD bootstrap chart installs the AppProject and Application
objects after the controller's CRDs exist. It is platform installation, not a
second owner of application Deployments.

## Four infrastructure boundaries

1. `terraform/bootstrap/`: persistent state/discovery storage and project DNS.
2. `terraform/cluster/`: the kOps-generated VPC, instances and cluster add-ons.
3. `terraform/`: Secrets Manager, TLS, workload IAM, backup storage, logs and
   non-secret deployment metadata in Parameter Store.
4. `terraform/platform/`: namespaces, storage, ingress, monitoring, logging and Argo CD.

Backend keys remain `bootstrap/terraform.tfstate`, `kops/terraform.tfstate`,
`services/terraform.tfstate` and `platform/terraform.tfstate`. Bootstrap's first
local application is a one-time prerequisite for the state bucket; subsequent
workflow runs use the existing bootstrap recovery key as a locked S3 backend.

The public path is Route 53 → AWS NLB with ACM TLS termination → NGINX → frontend/API.
PostgreSQL uses persistent EBS-backed storage. External Secrets resolves application
credentials from Secrets Manager at runtime. Prometheus/Grafana collect metrics;
Fluent Bit sends structured application logs to CloudWatch.

## Configuration boundaries

- Helm's `values-staging.yaml` and `values-production.yaml` describe environment
  behavior. Both environments share one chart and one cluster, with separate namespaces.
- `argocd/*-values.yaml` contains automatically refreshed runtime references and
  CI-selected image digests. Services apply reads Terraform-published SSM metadata,
  refreshes these files and commits the changes without copying outputs by hand.
- Image identity comes from the source commit, run ID and build date. Production
  receives staging's published digests without a rebuild.
- Secret values stay out of images, chart values and Git. Terraform state and plans
  may contain secret material and require private storage.

## Interview explanation

“Compose runs the application locally. GitHub Actions tests it against real
PostgreSQL, enforces coverage, builds and scans its images, then publishes them.
Terraform creates AWS and installs the Kubernetes platform. Actions updates image
digests in Git, and Argo CD deploys one Helm chart into staging and production.
Public acceptance checks gate promotion. Monitoring, scheduled backups and isolated
restore tests show how I would operate the application after deployment.”

This is a cost-conscious capstone cluster with one control-plane node, not a highly
available production platform. Explain that limitation and the shared-cluster
environment tradeoff explicitly in the presentation.
