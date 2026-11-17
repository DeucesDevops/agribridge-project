# kOps cluster

`cluster.yaml` is the cluster. kOps creates the VPC, the control plane, the
worker nodes, the AWS Load Balancer Controller, the EBS CSI driver, cert-manager
and the service-account issuer.

The issuer bucket and the state bucket are created by Terraform. Their names in
this file must match `discovery_bucket` and `kops_state_bucket`.

```sh
export KOPS_STATE_STORE=s3://kops-state-607
export CLUSTER_NAME=k8s.agribridge.deuces.dev

# New cluster
kops create -f kops/cluster.yaml
kops update cluster --name "$CLUSTER_NAME" --yes --admin

# Cluster that already exists
kops replace -f kops/cluster.yaml
kops update cluster --name "$CLUSTER_NAME" --yes

kops validate cluster --name "$CLUSTER_NAME" --wait 15m
kops export kubeconfig --admin --name "$CLUSTER_NAME"
```

Use kOps 1.36.2. The cluster Kubernetes version is 1.36.6. The full sequence,
including the public discovery bucket and the second Terraform apply, is
[docs/SETUP.md](../docs/SETUP.md).
