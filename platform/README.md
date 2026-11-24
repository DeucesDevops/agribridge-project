# Platform values

Helm values and the gp3 storage class now live in
`terraform/modules/platform/values/`. The releases are installed by
`terraform/modules/platform` on `terraform apply -var install_platform=true`.
See [terraform/modules/platform/README.md](../terraform/modules/platform/README.md).
