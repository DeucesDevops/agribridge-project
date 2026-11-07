# Kubernetes and cluster configuration

Keep the authored cluster-level configuration flat here:

| File | Purpose |
|---|---|
| `cluster.yaml` | kOps Cluster and InstanceGroup definitions |
| `nginx-ingress-values.yaml.tftpl` | NGINX/NLB settings, with Terraform-supplied ACM certificate reference |

Application Kubernetes definitions live in `helm/agribridge/templates/`, as the
assessment requires. Argo CD renders that chart. To inspect the selected release
without AWS access, run `make render ENV=staging` or `make render ENV=production`.
Do not apply a second raw-YAML copy alongside the Argo CD-managed application.

The cluster source contains a documentation-only API CIDR. The infrastructure
workflow supplies the trusted runner/VPN CIDRs and bootstrap discovery outputs
through `scripts/prepare-cluster.py`; never apply the source placeholder directly.
Generated Terraform belongs in ignored `terraform/generated/kops/`.
