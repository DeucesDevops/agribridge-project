# Terraform

This root creates the environment.

| File | What it creates |
|---|---|
| `network.tf` | VPC, two public subnets, internet gateway |
| `cluster.tf` | EKS 1.36, managed nodes, add-ons, OIDC provider, GitHub access entry |
| `dns.tf` | Public Route 53 zone, ACM certificate, validation records |
| `buckets.tf` | Private S3 bucket for PostgreSQL dumps |
| `secrets.tf` | QA, production and Grafana secrets |
| `iam.tf` | GitHub Actions role and the IRSA roles |
| `github.tf` | Actions variables and the `qa` and `production` environments |
| `platform.tf` | Helm releases, on the second apply |
| `modules/platform` | Load balancer controller, External Secrets, ExternalDNS, Loki, Tempo, Prometheus, Grafana, Promtail |

The nodes have no SSH key. The API is public and IAM decides who can call it.
Pod IPs come from the VPC CNI. The web Ingress still uses instance targets,
so the web Service stays a NodePort.

Grafana is `https://grafana.<zone>` on the same load balancer, with anonymous
access off. The admin password is `agribridge/grafana` in Secrets Manager.

## What stays outside this root

The state bucket is created by `scripts/bootstrap-state.sh`. Terraform stores
its state there, so it cannot create that bucket itself. The bucket is
versioned, encrypted and private. State holds the generated passwords. That
is why the bucket is not in git.

The parent domain `deuces.dev` is delegated at the registrar. Terraform prints
`name_servers` for the zone it creates. Someone has to publish those at the
registrar. Route 53 does not own the parent.

`GITHUB_TOKEN`, the Docker Hub token and the optional SonarQube token are
credentials for accounts this root does not own.

## Apply

```sh
cp backend.hcl.example backend.hcl   # or let scripts/bootstrap-state.sh write it
export GITHUB_TOKEN=...
terraform init -backend-config=backend.hcl
terraform apply -var install_platform=false
terraform apply -var install_platform=true
```

`scripts/apply-environment.sh` runs that sequence and the state migration
below. Pass `install_platform=true` on every later apply so a plan still
includes the charts.

The Helm and Kubernetes providers are configured in this root and passed into
the module. With `install_platform=false` the module is not created, so
Terraform does not contact the API. With `install_platform=true` it uses
`aws eks get-token`.

## Existing state

Run the imports in [docs/SETUP.md](../docs/SETUP.md) before the first apply
on the current account. In short:

- `terraform state rm` the kOps state bucket and the OIDC discovery bucket,
  and the resources that hang off them. The next apply would delete them
  otherwise. They can stay in the account until you delete them yourself.
- `terraform state rm data.aws_route53_zone.app`, then
  `terraform import aws_route53_zone.app ZONE_ID` for `agribridge.deuces.dev`.
- If the IRSA roles exist at `aws_iam_role.external_secrets[0]`, `state mv`
  them to `aws_iam_role.external_secrets`, and the same for the policy and
  for ExternalDNS.

The state bucket `agribridge-tfstate-237258628535` is not a resource in this
root. Point `backend.hcl` at it. Do not import it.

## Destroy

Destroy the platform module while the API still answers, remove the
ExternalDNS A and TXT records, then destroy the rest with
`install_platform=false`. The exact commands are in
[docs/SETUP.md](../docs/SETUP.md). `terraform destroy` on its own leaves the
load balancer and the DNS records behind and then fails on the VPC or the
zone.

The state bucket is not destroyed.
