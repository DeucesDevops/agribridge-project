# Terraform

Run application AWS services from `terraform/`. Three small folders handle the
steps that must run before or after those services. There is no `stacks/` layer.

| Order | Run Terraform in | Creates | State |
|---|---|---|---|
| 1 | `terraform/bootstrap/` | State/discovery buckets and project DNS zone | Local bootstrap state; encrypted recovery copy at `bootstrap/terraform.tfstate` in the state bucket |
| 2 | `terraform/cluster/` | VPC, EC2 nodes, IAM and generated kOps add-ons | S3 key `kops/terraform.tfstate` |
| 3 | `terraform/` | Secrets, TLS, registry, backups, logs and delivery IAM | S3 key `services/terraform.tfstate` |
| 4 | `terraform/platform/` | Kubernetes namespaces, storage, ingress, monitoring and opt-in Argo CD | S3 key `platform/terraform.tfstate` |

The separate state boundaries let Terraform create the cluster before connecting
to its Kubernetes API, and remove the platform while its controllers still run.
Staging and production share a cluster but use separate namespaces, runtime
secrets, databases and Helm values. This is a capstone deployment, with one
control-plane node; it does not provide control-plane high availability.

`main.tf`, `variables.tf` and `outputs.tf` are the normal starting points.
`modules/` holds the existing reusable resource definitions. Keep `moved.tf` and
provider lockfiles: they preserve resource-address history and dependency versions.
Do not put credentials or Terraform state in Git.

## Review before applying

Initialize each configuration with its existing backend key. For example, from
the repository root, after bootstrap has created the protected state bucket and
the private `.runtime/backend.hcl` file has been prepared:

```sh
terraform -chdir=terraform init -reconfigure \
  -backend-config=../.runtime/backend.hcl \
  -backend-config=key=services/terraform.tfstate
terraform -chdir=terraform plan

terraform -chdir=terraform/platform init -reconfigure \
  -backend-config=../../.runtime/backend.hcl \
  -backend-config=key=platform/terraform.tfstate
terraform -chdir=terraform/platform plan \
  -var-file=../../.runtime/platform.tfvars.json
```

Supply the account-specific inputs in [CONFIGURATION.md](../docs/CONFIGURATION.md).
The provisioning scripts currently apply all steps automatically; do not run
`make provision` or `make resume` during the approval-based preparation stages.
See [REBUILD-SESSION.md](../docs/REBUILD-SESSION.md) for the current approval gate.

## Generated cluster code

Edit `kubedefs/cluster.yaml`, then generate `terraform/generated/kops/` during the
approved infrastructure stage. Generated output is excluded from Git. CI validates
the available handwritten configurations and explicitly defers generated cluster
validation when that output is absent in its clean checkout.

```sh
kops update cluster k8s.agribridge.deuces.dev --target terraform --out terraform/generated/kops
python3 scripts/prepare-kops-module.py
python3 scripts/patch-kops-bootstrap.py
```

Preparation keeps provider configuration in `cluster/main.tf`, preserving the
explicit `aws.files` alias mapping. Do not hand-edit generated resource names.

## Folder migration

The previous four numbered entry points now live in `bootstrap/`, `cluster/`,
this directory, and `platform/`. Their module labels, resource names, provider
aliases, backend keys and `moved` blocks are unchanged. Local state and caches
move with each entry point; run `init -reconfigure` before a future plan to refresh
local module paths. A directory rename is not a reason to create new state.
Historical verification documents retain the paths used when their checks ran.
