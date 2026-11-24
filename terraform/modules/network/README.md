# Network

VPC, public subnets, internet gateway, route table, and DHCP options for the
kOps cluster. `kops/cluster.yaml` sets `networkCIDR` to `172.20.0.0/16` and two
public subnets, `172.20.0.0/17` in `us-east-1a` and `172.20.128.0/17` in
`us-east-1b`.

There is no NAT gateway. Both subnets are public. The route table sends
`0.0.0.0/0` and `::/0` to the internet gateway. Calico pod IPs are not routable
from the VPC, which is why the load balancer uses instance targets.

`main.tf` and `outputs.tf` are generated. `scripts/render-kops-terraform.sh`
runs `kops update cluster --target=terraform` and
`scripts/patch_kops_terraform.py` moves the network resources out of the kOps
file into this module. The cluster module receives `vpc_id`, the subnet map,
and the route table id as variables. This module has no provider or backend
blocks.
