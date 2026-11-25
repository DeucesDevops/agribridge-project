# Cluster

Control plane, node groups, node IAM, and security groups for the kOps cluster.

| File | Contents |
|---|---|
| `main.tf` | AMI lookup, autoscaling groups, launch templates, etcd volumes, add-on objects |
| `iam.tf` | Control-plane role, node role, instance profiles, and the IRSA roles kOps renders |
| `security-groups.tf` | Control-plane and node security groups |
| `data/` | Policies and nodeup configuration published with the S3 objects |

The VPC and subnets live in `../network`. This module takes their ids as
variables. `aws.files` is passed from the environment root for the objects
kOps uploads. There is no provider or backend block here.

`scripts/render-kops-terraform.sh` writes kOps output to `kubernetes.tf` in
this directory, then `scripts/patch_kops_terraform.py` splits that file into
the ones above and deletes `kubernetes.tf`. Re-render after
`kops/cluster.yaml` changes and commit the result. The certificates in the
state bucket and these files have to come from the same run.
