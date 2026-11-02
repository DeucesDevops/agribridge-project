# AgriBridge teardown — completed 1 November 2026

AWS account: `237258628535`. Project region: `us-east-1`.
The running deployment was removed on 30 October. After explicit approval to
permanently delete the retained data without snapshots, the remaining project
storage, DNS, certificate and networking were deleted on 1 November.

## Verified final status

| Component | Result |
|-----------|--------|
| Applications and platform | Both application releases, monitoring, Fluent Bit, External Secrets, NGINX and failed Traefik Helm releases uninstalled on 30 October |
| Cluster | All three instances terminated; no project instances remain |
| Auto Scaling and launch templates | All three groups, lifecycle hooks and templates removed |
| Public ingress | NLB and target group removed; no ELBv2 load balancers or target groups remain in the region |
| EBS | Three root disks deleted on termination; all six retained project volumes (92 GiB) permanently deleted on 1 November |
| Snapshots | None created; no owned snapshots found in the region |
| S3 | All four project buckets deleted, including 121 object versions/delete markers |
| Networking | Dedicated VPC, two subnets, custom route table/associations, gateway, security groups and DHCP options deleted |
| DNS and TLS | Project hosted zone and its records deleted; ACM certificate deleted |
| IAM | Twelve project/cluster roles, their policies/attachment, two instance profiles and both project-created OIDC providers deleted; no other roles referenced those providers |
| ECR | Both AgriBridge repositories deleted |
| SSM | Both deployment parameters deleted |
| Logs | `/agribridge/containers` deleted |
| Event handling | Four project EventBridge rules/targets and SQS queue deleted |
| Secrets | Five project secrets marked for deletion on 30 October, with permanent deletion scheduled for 6 November 2026 |

AWS [does not charge for secrets marked for deletion](https://docs.aws.amazon.com/secretsmanager/latest/userguide/manage_delete-secret.html).
Their seven-day recovery window remains in place; they are inaccessible unless
restored. AWS removes them after that window. No active project secret remains.

The final direct API inventory confirmed no project instances, volumes, subnets,
gateways, DHCP options, VPC, load balancers, target groups, launch templates,
Auto Scaling groups, buckets, hosted zone, certificate, IAM roles/profiles/OIDC
providers, ECR repositories, SSM parameters, log group, rules or queue remained.
Already accrued AWS usage remains payable. This is a project teardown record,
not an account-wide guarantee of zero charges across every AWS service.

## Deleted retained data

No disk snapshots or database backups were taken before the approved deletion.
The following volume data is permanently erased:

| Data | Volume | GiB |
|------|--------|----:|
| Production PostgreSQL | `vol-0e1c0c47bf67ed134` | 20 |
| Staging PostgreSQL | `vol-0485af89abfb9758e` | 20 |
| Prometheus | `vol-06fbf0d11b62ebe27` | 10 |
| Grafana | `vol-0e68fecbb7a1d3361` | 2 |
| etcd events | `vol-0b293b5d0877f0271` | 20 |
| etcd main | `vol-08c9b00a3e3bc2707` | 20 |

Deleted S3 buckets and their entire contents/version history:

- `agribridge-backups-237258628535`: empty bucket.
- `agribridge-oidc-237258628535`: two public verification-key objects.
- `kops-state-607`: 76 versions; contents verified to belong to this cluster prefix.
- `agribridge-tfstate-237258628535`: 31 versions and 12 delete markers; no active lock found.

Deleted hosted zone: `agribridge.deuces.dev`, ID `Z01326791Q0OJZ6W079KR`.
Deleted ACM certificate: `2c8da187-6243-4466-ab59-c2991431e238`.
Deleted VPC: `vpc-03ca1ce356118677a`.

The Namecheap domain registration and any parent-domain delegation outside this
AWS hosted zone were not changed. Remove stale delegation when appropriate before
using this subdomain elsewhere.

## Terraform records and source preserved

Terraform provider processes failed their plugin handshake in this session.
Removal therefore used Helm and AWS APIs, rather than a successful Terraform
`destroy`. Do not describe the old Terraform state as reconciled or empty.

Source code, modules, cluster source YAML and guides remain. The last three remote
states and local bootstrap state are archived privately under
`.runtime/teardown-2026-10-30/`, alongside a final resource checkpoint. These files
contain sensitive values and must not be committed. The S3 bootstrap recovery key
did not exist; the actual local bootstrap state was archived instead. Terraform
archives are not database or disk backups.

The old working state/backend cache refers to resources and remote buckets that
no longer exist. Before rebuilding, reconcile/archive the old working state and
initialize the chosen fresh backend. Follow the rebuild/configuration guides.
`make provision`, Terraform apply or equivalent actions can create resources and
charges again; nothing should provision automatically as part of this teardown.
The deployment role was deleted, so the old pipeline cannot authenticate to AWS.

## Other account resources preserved

These pre-existing resources were outside the AgriBridge Terraform teardown:

| Resource | Remaining state/cost consideration |
|----------|-------------------------------------|
| `10alytics-server` — `i-0a65ec372f9a6bf9b` | Stopped; its 15 GiB disk `vol-098e88023de630db0` remains billable |
| `kops` — `i-0c1de55b9588024fe` | Stopped; its 8 GiB disk `vol-010511fc008dd1112` remains billable |
| `taskflow.deuces.dev` | Separate Route 53 hosted zone remains billable |
| `/aws/lambda/test` | Unrelated log group retained |
| Default and project-management VPCs, account/service roles and billing alarm | Left unchanged |

The final region inventory showed only those two stopped hosts and two EBS volumes;
no Elastic IPs, NAT gateways or owned snapshots were present in `us-east-1`.
The earlier read across 17 enabled regions was not a full billing audit of every
AWS service. No deletion of other projects was inferred from approval to remove
AgriBridge.

## Approval history

Automatic review initially rejected permanent volume and network/DNS deletion on
30 October because irreversible data/configuration loss was not clearly approved.
The user explicitly approved permanent removal of all remaining AgriBridge data,
S3 contents, DNS, certificate and networking without snapshots on 1 November.
Deletion then succeeded through the approved AWS connection; no rejected action
was bypassed.
