# Kubernetes definitions

Keep the authored Kubernetes configuration flat in this folder:

| File | Purpose |
|---|---|
| `cluster.yaml` | kOps Cluster and three InstanceGroup definitions |
| `nginx-ingress-values.yaml.tftpl` | Ingress controller and NLB values; Terraform supplies the ACM certificate ARN |

Generated cluster Terraform belongs in `terraform/generated/kops/`, called by
`terraform/cluster/`.

The application chart remains in `helm/agribridge/`, as required by the course.
To inspect all its rendered Kubernetes definitions in one file after AWS
configuration exists:

```sh
bash scripts/render-manifests.sh staging IMAGE_TAG
```

This writes the ignored `kubedefs/staging-rendered.yaml`, including the Namespace.
It references secrets without containing their values. Do not apply it alongside
an existing Helm release or Argo CD Application. The current delivery workflow
still uses Helm directly; Argo CD ownership is introduced in stage 6.

The API CIDR in `cluster.yaml` is a documentation-only placeholder. Use
`make plan-cluster` to render the private `.runtime/cluster.yaml` with your
workstation's current public IPv4 (/32), or supply approved VPN CIDRs through
`AGRIBRIDGE_API_CIDRS`. Do not apply the source manifest directly. Root disks
are explicitly encrypted 32 GiB gp3 volumes; each of the two etcd disks is
encrypted 20 GiB gp3.
