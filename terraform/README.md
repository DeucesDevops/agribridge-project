# Terraform

Run Terraform from the four entry points below. Reusable child modules live under
`modules/`; they contain resource definitions and declare provider requirements.
Provider configurations and state backends belong to entry points only.

| Entry point | Responsibility | Existing state location |
|-------------|----------------|-------------------------|
| `bootstrap/` | State/discovery buckets, existing kOps state bucket and public DNS zone | Local `bootstrap/terraform.tfstate`, backed up under `bootstrap/terraform.tfstate` in the protected bucket |
| `cluster/` | kOps EC2 cluster, networking, node identities and generated add-ons | S3 key `kops/terraform.tfstate` |
| `services/` | Registry, runtime secrets, TLS, backups, logs, GitHub identity and deployment handoff | S3 key `services/terraform.tfstate` |
| `platform/` | Kubernetes namespaces, controllers, storage, ingress, monitoring and deployment identities | S3 key `platform/terraform.tfstate` |

## Child modules

| Module | Owns | Main outputs |
|--------|------|--------------|
| `bootstrap` | Protected state buckets, discovery and Route 53 zone | State and discovery locations |
| `kops-cluster` | kOps-generated VPC, subnets, EC2/ASGs, IAM and bootstrap resources | Cluster, VPC, subnets and identity details |
| `registry` | Docker Hub image addresses; retains pre-existing ECR repositories | Docker Hub repository URLs |
| `runtime-secrets` | Environment-specific secret entries, generated values and ESO identity | Secret ARNs and ESO role |
| `tls` | ACM certificate and DNS validation | Validated certificate ARN |
| `backups` | Private backup storage and scoped environment identities | Bucket and backup roles |
| `observability` | CloudWatch log group, logging role and SSM node diagnostics policy | Log group and logging role |
| `deployment-config` | SSM deployment configuration | Parameter ARNs |
| `github-delivery` | GitHub OIDC provider and narrowly scoped release role | Pipeline role ARN |
| `kubernetes-platform` | Cluster platform Helm releases, storage, namespaces, deploy RBAC and ingress DNS | Ingress hostname |

Staging and production share one cluster and the AWS service entry point. Their
namespaces, secrets, databases and release values stay separate. There is no second
copy of these modules for each environment and no EKS/RDS/ElastiCache module: this
deployment uses kOps and in-cluster PostgreSQL/Redis.

## Existing-resource migration

The four `moved.tf` files map all 141 existing resource blocks into their child
modules. Entire `for_each` resources are moved, preserving the individual keys,
including the six generated runtime passwords and the namespace deployment tokens.
Do not remove these migration blocks while older state snapshots may still be used.

The entry point paths changed, but their S3 keys did not. Initialize from the new
paths; do not create a new state or import all resources again. `scripts/provision.sh`
accepts both the old and new bootstrap addresses when adopting pre-existing resources.

Run `bash scripts/provision.sh` for the complete path. To resume platform installation
on the existing cluster, use `bash scripts/resume-platform.sh`. Before the first
module migration apply, inspect the Terraform plan: the address moves themselves
must not destroy or replace resources. Live plan verification is still pending;
see `docs/VERIFICATION.md`.

## Regenerating the cluster module

Edit `kops/cluster.yaml`, then let `scripts/provision.sh` run kOps with Terraform
output directed to `modules/kops-cluster`. `scripts/prepare-kops-module.py` removes
the generated provider configurations and updates the root output forwarding;
`scripts/patch-kops-bootstrap.py` applies the service webhook bootstrap fix.
The `aws.files` provider alias is explicitly passed from `cluster/` to the module.
Do not hand-edit generated launch templates, resource names or policy documents.
