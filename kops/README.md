# kOps cluster

`cluster.yaml` is the cluster spec. kOps 1.36.2 turns it into Terraform with
`scripts/render-kops-terraform.sh`. The patch script puts the VPC, public
subnets, and routes in `terraform/modules/network` and the instances, IAM, and
security groups in `terraform/modules/cluster`. There is no NAT gateway.
`terraform apply` creates them. The state bucket is `s3://kops-state-607`. The
service-account issuer is published to `s3://agribridge-oidc-237258628535`.

The control plane is one `t3.medium`. The workers are two `t3.large` nodes,
which is enough for the monitoring stack. `sshAccess` is empty, and the
launch templates have no SSH key.

```sh
export KOPS_STATE_STORE=s3://kops-state-607
export KOPS_CLUSTER_NAME=k8s.agribridge.deuces.dev
./scripts/render-kops-terraform.sh
```

Use kOps 1.36.2. The cluster Kubernetes version is 1.36.6. The full sequence
is [docs/SETUP.md](../docs/SETUP.md).
