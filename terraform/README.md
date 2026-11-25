# Terraform

```
terraform/
├── modules/
│   ├── network/          # VPC, public subnets, internet gateway, route tables
│   ├── cluster/          # control plane, node groups, IAM, security groups
│   │   ├── main.tf
│   │   ├── iam.tf
│   │   ├── security-groups.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dns/              # Route 53 zone, ACM certificate, validation records
│   ├── storage/          # S3 buckets, backups, KMS, Secrets Manager
│   ├── identity/         # GitHub OIDC, CI role, IRSA roles
│   └── platform/         # Helm: external-dns, Argo CD, monitoring
│       ├── main.tf
│       ├── argocd.tf
│       ├── monitoring.tf
│       └── values/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── backend.hcl
│   │   ├── providers.tf
│   │   └── terraform.tfvars
│   └── production/
│       ├── main.tf
│       ├── backend.hcl
│       ├── providers.tf
│       └── terraform.tfvars
└── bootstrap/            # state bucket, local state, applied first
    └── main.tf
```

kOps renders one file. `scripts/render-kops-terraform.sh` writes it and
`scripts/patch_kops_terraform.py` splits the VPC and routes into `modules/network`
and the instances, IAM, and security groups into `modules/cluster`. The subnets
are public, so the network module has no NAT gateway. The AWS Load Balancer
Controller is installed by kOps, not by a second Helm release.

`environments/production` is the root `scripts/apply-environment.sh` applies.
`install_platform=false` builds AWS and the cluster. `install_platform=true`
adds `module.platform["production"]`. `environments/dev` is a second root with
its own state key. Its kOps spec is still the production render, so leave it
until `kops/cluster.yaml` describes a dev cluster. Commands and the state
migration are in [environments/production/README.md](environments/production/README.md).

A rebuild starts with `scripts/bootstrap-state.sh`. From the repository root:

```sh
./scripts/bootstrap-state.sh
terraform -chdir=terraform/environments/production init -backend-config=backend.hcl
./scripts/render-kops-terraform.sh
terraform -chdir=terraform/environments/production apply -var install_platform=false
terraform -chdir=terraform/environments/production apply -var install_platform=true
```

The apply script runs that sequence and pauses for DNS delegation between the
two applies. `scripts/terraform-validate.sh` checks formatting and runs
`terraform init -backend=false` and `terraform validate` in every module, both
environments, and `bootstrap`.
