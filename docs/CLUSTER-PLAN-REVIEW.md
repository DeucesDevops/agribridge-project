# Cluster plan review — 2 November 2026

Status: Bernard approved this exact plan on 2 November 2026. The agent's apply
attempt stopped during STS credential validation because its restricted shell
could not resolve `sts.us-east-1.amazonaws.com`. Subsequent read-only AWS checks
confirm all three planned instances are running and Healthy/InService in their
Auto Scaling groups, and remote Terraform state has been written. The complete
supplied apply transcript confirms **90 added, 0 changed, 0 destroyed**.
The supplied kOps validation now confirms cluster readiness, all three nodes are
Ready on v1.36.6, and the three required controller deployments rolled out.
A refreshed no-change Terraform plan remains pending. The command below records
the approved apply and is not a recommendation to repeat it now.
This stage starts chargeable compute. The working agreement in REBUILD-SESSION.md
requires a resource and cost review before applying the cluster.

## Saved artifact

- Account: `237258628535`; region: `us-east-1`.
- Cluster: `k8s.agribridge.deuces.dev`.
- Plan: `.runtime/cluster-20261102T124547Z-22210.tfplan`.
- Readable output: `.runtime/cluster-20261102T124547Z-22210.txt`.
- SHA-256: `7c30725fbb56dc43f96fa0ca5744b4740f547b62bb7f885670c5959916ef6f17`.
- Summary: **90 additions, 0 changes, 0 deletions**; no warnings in the readable
  output. The saved plan archive contains an empty prior cluster resource state.

Public DNS, bootstrap outputs and account identity passed in Bernard's terminal.
Planning saved kOps metadata and a bootstrap-state backup in S3. These writes
are distinct from starting EC2 instances; no cluster apply has been performed
by this session.

## Resources and access

| Planned component | Quantity/configuration |
|---|---|
| Control plane | One t3.medium in us-east-1a |
| Workers | Two t3.medium, one each in us-east-1a and us-east-1b |
| Root disks | Three encrypted gp3 disks, 32 GiB each |
| etcd disks | Two encrypted gp3 disks, 20 GiB each, in us-east-1a |
| Total disks | 136 GiB, baseline 3,000 IOPS and 125 MiB/s per volume |
| Public IPv4 | Three expected, one per node |
| Network | One VPC, two public subnets, internet gateway and routing |
| Identity | Seven roles and inline policies, two instance profiles, OIDC provider |
| Cluster coordination | SQS queue, four EventBridge rules and four targets, three lifecycle hooks |
| State/addon content | 27 S3 objects |

Three Auto Scaling groups each have minimum and maximum size one. The API's
TCP 443 ingress is restricted to the operator's public /32; SSH access is not
enabled. Other ingress is between cluster security groups. Outbound internet
access is allowed. The generated DNS controller permissions reference current
zone `Z098670523YNOQ1LDBYDG`.

No NAT gateway, load balancer, application database volume or application release
is created by this plan. Controllers installed with the cluster can create
additional resources when later Kubernetes objects request them.

The single control plane is appropriate for this capstone demonstration but
does not provide control-plane high availability. Two worker availability zones
do not remove that limitation.

## Estimated running cost

Read-only AWS Price List API queries on 2 November 2026 confirmed the following
us-east-1 public rates, before taxes or account-specific credits/discounts:

| Component | Rate and calculation | Approximate cost per day |
|---|---|---|
| EC2 | 3 × $0.0416/hour × 24 | $3.00 |
| gp3 | 136 GiB × $0.08/GB-month ÷ 30 days | $0.36 |
| Public IPv4 | 3 × $0.005/hour × 24 | $0.36 |
| Cluster subtotal | Rounded from $3.7179/day | **$3.72** |

This is a subtotal for continuously running planned nodes, disks and addresses.
It excludes the existing hosted zone, S3 storage/requests and etcd backups,
EventBridge/SQS usage, data transfer, CPU surplus credits, taxes and any later
load balancers, application storage, monitoring or logging. Older unrelated
account resources remain outside this estimate.

Sources: AWS Price List GetProducts responses for AmazonEC2 t3.medium Linux
shared tenancy (SKU NN4EGUUQRWVYP98C), gp3 storage (JG3KUJMBRGHV3N8G), and
AmazonVPC in-use public IPv4 (4GQUNXTFWVSGPUZK). See also the official
[EBS pricing](https://aws.amazon.com/ebs/pricing/) and
[VPC pricing](https://aws.amazon.com/vpc/pricing/) pages.

## Apply after approval

Run from the project root in the normal terminal, after approving this exact plan:

```sh
terraform -chdir=terraform/cluster apply -input=false \
  "$PWD/.runtime/cluster-20261102T124547Z-22210.tfplan"
```

If the configuration or plan changes, review the new artifact before applying.
After apply, export an administrative kubeconfig privately, validate the cluster,
and check a fresh Terraform plan before proceeding to the next staged change.
Do not run `make provision` or `make resume` during staged review; those commands
apply additional infrastructure automatically.
