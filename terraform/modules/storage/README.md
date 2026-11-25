# Storage

S3 buckets this account keeps for the cluster, plus the KMS key and Secrets
Manager secrets the application reads.

| Bucket | Access |
|---|---|
| kOps state | Private, versioned, encrypted. `prevent_destroy` is set. |
| OIDC discovery | Objects are world-readable so AWS can fetch the issuer. No public ACL. `prevent_destroy` is set. |
| Backups | Private, versioned, encrypted. Dumps expire after 30 days. |

The backup bucket name is `backup_bucket` when that variable is set, otherwise
`agribridge-backups-<account id>`.

Secrets Manager holds `agribridge/production` (`PGPASSWORD`, `JWT_SECRET`,
`SEED_PASSWORD`) and `agribridge/grafana`. The passwords are `random_password`
resources. Moving their addresses without the `moved` blocks in the production
root would generate new passwords.

The Terraform state bucket is not here. `terraform/bootstrap` creates it,
because this module's state is stored in that bucket. This module has no
provider or backend blocks.
