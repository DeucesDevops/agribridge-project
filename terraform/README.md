# Terraform

GitHub Actions runs the four infrastructure boundaries in dependency order. The
root remains the entry point for AWS application services; there is no stacks layer.

| Order | Directory | Responsibility | Existing S3 state key |
|---|---|---|---|
| 1 | `bootstrap/` | Persistent state/discovery storage and project DNS | `bootstrap/terraform.tfstate` |
| 2 | `cluster/` | VPC, EC2 nodes, IAM and kOps add-ons | `kops/terraform.tfstate` |
| 3 | This directory | Secrets, TLS, registry references, backups, logs and workload IAM | `services/terraform.tfstate` |
| 4 | `platform/` | Namespaces, storage, ingress, monitoring, logging and Argo CD | `platform/terraform.tfstate` |

The cluster must exist before Terraform connects to its Kubernetes API. Remove
platform resources while controllers still run, then remove cluster infrastructure.
Staging/production share one cluster but have separate namespaces, secrets and
PostgreSQL storage. One control-plane node is a capstone cost tradeoff.

## Workflow

Dispatch `.github/workflows/infrastructure.yaml` from `main`, selecting a stage
and `plan`, `apply` or `destroy`. An apply/destroy run first creates its saved plan,
then waits for the configured `infrastructure` environment approval. Full plans
are encrypted in the private state bucket, not uploaded as Actions artifacts.
The apply job checks the bundle checksum and applies that exact plan.

The initial local bootstrap creates the state bucket once. For this existing
project, recover its existing authoritative state instead of recreating retained
resources. Actions generates an ignored `bootstrap/backend_override.tf` to use
the original S3 recovery key with locking. Once that key is workflow-managed,
never apply an old workstation copy. See [reproduction](../docs/REPRODUCTION.md).

## Files to edit

- `main.tf`: AWS service/module composition.
- `providers.tf`: service provider account/region configuration.
- `variables.tf`, `outputs.tf`: inputs and handoffs.
- `terraform.tfvars.example`: documented service inputs, without secret values.
- `modules/`: reusable resource definitions.
- `kubedefs/cluster.yaml`: authored kOps configuration.

Keep provider lockfiles, resource addresses and `moved.tf` history intact.
Directory organization is not a reason to create fresh state or import resources
under different addresses.

`prepare-cluster.py generate` renders the runner's allowed CIDRs and bootstrap
outputs, generates `generated/kops/`, keeps providers in the handwritten root and
preserves the pinned webhook bootstrap fix. It verifies the generated output
contract instead of silently rewriting the checked-in outputs. Generated cluster
files stay ignored and travel privately with the exact plan for cluster apply.

Platform inputs come directly from the services outputs. Services application
refreshes `argocd/*-values.yaml` from non-secret SSM metadata automatically.
Runtime secret values are never copied into GitOps files.

Runner/access prerequisites and plan review are documented in
[CONFIGURATION.md](../docs/CONFIGURATION.md). Destruction guards and retained-data
handling are documented in [OPERATIONS.md](../docs/OPERATIONS.md).
