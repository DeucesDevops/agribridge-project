# Platform values

Helm values and the gp3 storage class now live in
`terraform/modules/platform/values/`. The releases are installed by
`terraform/modules/platform` on `terraform -chdir=terraform/environments/production apply -var install_platform=true`.
See [terraform/modules/platform/README.md](../terraform/modules/platform/README.md).
