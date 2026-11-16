# Terraform

Run Terraform from an authorized terminal on your existing kOps management
instance. GitHub Actions handles application delivery; infrastructure has no
workflow, self-hosted runner, plan bundle or extra GitHub OIDC roles to configure.

| Order | Directory | Responsibility | S3 state key |
|---|---|---|---|
| 1 | `bootstrap/` | Retained state/discovery storage and project DNS | `bootstrap/terraform.tfstate` |
| 2 | `cluster/` | VPC, EC2 nodes, IAM and kOps add-ons | `kops/terraform.tfstate` |
| 3 | This directory | Secrets, TLS, backup storage, logs and workload IAM | `services/terraform.tfstate` |
| 4 | `platform/` | Namespaces, storage, ingress, monitoring, logging and Argo CD | `platform/terraform.tfstate` |

These boundaries preserve existing resource addresses and state. The cluster
must exist before the platform can connect to Kubernetes. During teardown,
remove the platform while Kubernetes and its controllers are still available.

## Standard commands

From the repository root, initialize a boundary with its **existing** state key:

```sh
terraform -chdir=terraform init -reconfigure -lockfile=readonly \
  -backend-config=backend.hcl.example \
  -backend-config=key=services/terraform.tfstate
terraform -chdir=terraform plan -var-file=../.runtime/services.tfvars \
  -out=../.runtime/services.tfplan
terraform -chdir=terraform apply ../.runtime/services.tfplan
```

Review each plan before applying it. Plans and state can contain credentials;
keep `.runtime/` private and out of Git. Never switch keys or apply an old
workstation state to resolve drift. Retain provider lockfiles and `moved.tf`.

For the complete bootstrap → cluster → services → platform sequence, including
state recovery, administrator CIDRs and GitOps references, follow
[REPRODUCTION.md](../docs/REPRODUCTION.md).

## Files to edit

- `backend.hcl.example`: non-secret shared S3 backend settings.
- `main.tf`, `variables.tf`, `outputs.tf`: AWS services and handoffs.
- `terraform.tfvars.example`: non-secret service inputs.
- `modules/`: reusable resource definitions.
- `cluster/cluster.yaml`: authored kOps Cluster and InstanceGroups.

`prepare-cluster.py` remains a focused compatibility helper: it renders narrow
administrator CIDRs, checks DNS delegation, generates ignored kOps Terraform and
preserves the pinned load-balancer webhook bootstrap fix. It does not apply
infrastructure. Shared NGINX/NLB Helm values live in `helm/platform/`.
