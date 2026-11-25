# Bootstrap

Creates the Terraform state bucket. The production and dev environments store
their state in this bucket, so this root keeps local state and cannot use that
backend. A rebuild starts with `scripts/bootstrap-state.sh`. The script runs
`terraform -chdir=terraform/bootstrap apply` and writes
`terraform/environments/production/backend.hcl` and
`terraform/environments/dev/backend.hcl` when a file is missing.

The bucket is versioned, encrypted with AES256, and blocked from public
access. `prevent_destroy` is set. Tear down does not delete it. Remove it
with `aws s3 rb` only after you no longer need the state. The default name is
`agribridge-tfstate-<account id>`.

Local `terraform.tfstate` holds the bucket id. It is gitignored. Do not commit
it.
