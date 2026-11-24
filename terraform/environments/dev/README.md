# Dev

Second root. It calls the same modules as production and stores state at
`agribridge/dev/terraform.tfstate` in the bootstrap bucket.

`scripts/apply-environment.sh` applies production. The kOps render in
`terraform/modules/cluster` and `terraform/modules/network` is the production
cluster from `kops/cluster.yaml` (`k8s.agribridge.deuces.dev`, public subnets,
no NAT). Do not apply this root against the production account until that
spec is a dev cluster. The bucket names in `terraform.tfvars` are separate
from production so a dev apply does not adopt `kops-state-607` or the
production zone.

`install_platform` is false until a dev API answers and
`kops export kubeconfig --admin` has written a kubeconfig for this cluster.
