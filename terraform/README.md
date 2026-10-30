# Terraform: start here

There are three areas. **Run stacks, edit modules, regenerate generated code.**

| Folder | Contains | What you do |
|--------|----------|-------------|
| `stacks/` | Four runnable configurations | Run init, plan and apply here |
| `modules/` | Reusable hand-written resource definitions | Edit how a service is built |
| `generated/kops/` | Generated cluster resources and bootstrap data | Regenerate from `kops/cluster.yaml` |

## Run order

| Order | Stack | Responsibility | Existing state location |
|-------|-------|----------------|-------------------------|
| 1 | `stacks/01-bootstrap/` | State/discovery buckets and DNS zone | Local state here; recovery copy at `bootstrap/terraform.tfstate` in the protected bucket |
| 2 | `stacks/02-cluster/` | VPC, EC2 nodes, node IAM and generated add-ons | S3 key `kops/terraform.tfstate` |
| 3 | `stacks/03-services/` | Secrets, certificates, registry, backups, logs and delivery IAM | S3 key `services/terraform.tfstate` |
| 4 | `stacks/04-platform/` | Namespaces, storage, ingress, monitoring and deployment access | S3 key `platform/terraform.tfstate` |

Normally run from the project root:

```sh
make provision   # All four stacks, in order
make resume      # Existing cluster: refresh services and finish the platform
```

For direct inspection, work in a numbered stack:

```sh
terraform -chdir=terraform/stacks/04-platform init -reconfigure \
  -backend-config=../../../.runtime/backend.hcl \
  -backend-config=key=platform/terraform.tfstate
terraform -chdir=terraform/stacks/04-platform plan \
  -var-file=../../../.runtime/platform.tfvars.json
```

The scripts generate the private runtime inputs. A fresh checkout needs the setup
in [the rebuild guide](../docs/REBUILD-GUIDE.md).

## Files inside a hand-written Terraform folder

| File | Meaning |
|------|---------|
| `main.tf` | What gets built; requirements and root providers where applicable |
| `variables.tf` | Accepted inputs |
| `outputs.tf` | Values handed to the next step |
| `moved.tf` | Existing resource-address migration history; preserve it |
| `.terraform.lock.hcl` | Locked provider versions for a runnable stack; commit it |

Child modules declare provider requirements in `main.tf`. Provider configurations
and backends belong to the numbered stacks. Generated code retains its own
`kubernetes.tf` and `data/` layout.

## Find the module you need

| Change | Module |
|--------|--------|
| State buckets, discovery and DNS zone | `modules/bootstrap/` |
| Docker Hub addresses and retained ECR repositories | `modules/registry/` |
| Runtime secrets and ESO IAM role | `modules/runtime-secrets/` |
| ACM certificate and validation | `modules/tls/` |
| Backup storage, retention and roles | `modules/backups/` |
| CloudWatch and node diagnostics | `modules/observability/` |
| GitHub OIDC and release role | `modules/github-delivery/` |
| SSM deployment handoff | `modules/deployment-config/` |
| NGINX/NLB, monitoring, storage, namespaces and deploy access | `modules/kubernetes-platform/` |

The cluster is one generated module under `generated/kops/`. Its VPC and nodes
are generated together by kOps. There is no EKS module. Staging and production
share one cluster and AWS service stack but have separate namespaces, secrets,
databases and Helm values.

## Moving from the previous folders

Only local paths changed. Module labels, resource names, provider aliases,
backend keys and existing `moved.tf` contents are preserved. This layout needs no
additional resource-address migration or live apply. Reinitialize the new stack
directory before a later plan; do not start a new remote state.

Bootstrap's local state and each stack's local cache moved with their directory.
The original migration blocks still cover 141 resource definitions; retain them.

## Regenerate the cluster

Edit the flat `kops/cluster.yaml`. The provisioning script then runs:

```sh
kops update cluster k8s.agribridge.deuces.dev --target terraform --out terraform/generated/kops
python3 scripts/prepare-kops-module.py
python3 scripts/patch-kops-bootstrap.py
```

Preparation keeps providers in stack 02 and forwards generated outputs. The patch
scopes the AWS load-balancer service webhook for cold bootstrap. Keep the explicit
`aws.files` provider mapping in the cluster stack.
