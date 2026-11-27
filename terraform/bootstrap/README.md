# Bootstrap

Creates the Terraform state bucket. The production environment stores its
state in this bucket, so this root keeps local state and cannot use that
backend. `scripts/bootstrap-state.sh` runs `terraform apply` here and writes
`terraform/environments/production/backend.hcl` and
`terraform/environments/dev/backend.hcl` when a file is missing. Those files
set `use_lockfile = true`, which is Terraform's S3 native lock. This root does
not create a DynamoDB lock table.

The bucket is versioned, encrypted with AES256, and blocked from public
access. `prevent_destroy` is set. Tear down does not delete it. Remove it
with `aws s3 rb` only after you no longer need the state. The default name is
`agribridge-tfstate-<account id>`.

Local `terraform.tfstate` holds the bucket id. It is gitignored. Do not commit
it.
