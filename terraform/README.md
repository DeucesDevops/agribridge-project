# Terraform

This root creates everything around the kOps cluster. It does not create the
cluster. kOps does that from `kops/cluster.yaml`.

| File | What it creates |
|---|---|
| `buckets.tf` | kOps state bucket and the public OIDC discovery bucket |
| `dns.tf` | ACM certificate and its Route 53 validation records |
| `ecr.tf` | `agribridge-api` and `agribridge-web` repositories |
| `secrets.tf` | QA and production Secrets Manager secrets |
| `iam.tf` | GitHub Actions role, and the External Secrets and ExternalDNS roles |

The External Secrets and ExternalDNS roles are created only when
`attach_irsa = true`, because kOps has to create the OIDC provider first.
Their trust policy uses that provider and the audience `amazonaws.com`.

```sh
cp backend.hcl.example backend.hcl
# Edit backend.hcl and set the state bucket you created by hand.
terraform init -backend-config=backend.hcl
terraform apply
```

After `kops update cluster` succeeds:

```sh
terraform apply -var attach_irsa=true
```

State for this root lives in the bucket from `backend.hcl`, under
`agribridge/terraform.tfstate`. Do not point it at an older state key from the
previous bootstrap, services or platform roots. Those roots are gone.

`terraform destroy` does not delete the cluster. Delete the cluster with kOps
first. The state bucket and the discovery bucket have `prevent_destroy` set.
