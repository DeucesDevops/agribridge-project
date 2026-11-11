# Platform Helm configuration

`nginx-ingress-values.yaml.tftpl` configures the shared NGINX ingress controller
and its AWS Network Load Balancer. Terraform renders the ACM certificate ARN and
installs the upstream chart through `terraform/platform/main.tf`.

This directory contains values for shared platform services. The application
chart and its environment values remain in `helm/agribridge/`; Argo CD reconciles
that chart into staging and production. Inspect an application release without
AWS using `make render ENV=staging` or `make render ENV=production`.

The kOps Cluster and InstanceGroup source is
`terraform/cluster/cluster.yaml`, rendered by `scripts/prepare-cluster.py` before
cluster provisioning. Generated Terraform stays in ignored
`terraform/generated/kops/`.
