# Stage 5 — Kubernetes platform plan preparation

Current status: Bernard applied the reviewed platform plan successfully,
**9 added, 0 changed, 0 destroyed**. Post-apply readiness and drift checks are
being completed. Application deployment, Argo CD reconciliation and monitoring
demonstrations remain pending.

From the project root in the normal terminal:

```sh
make plan-platform
```

This checks AWS account identity, the private kubeconfig's current context and
API server, then waits for the existing core controllers. It saves a refreshed
services plan and requires `No changes` before continuing. It regenerates
`.runtime/platform.tfvars.json` from current service outputs, replacing stale
pre-teardown inputs after saving a private recovery copy. It initializes the
original `platform/terraform.tfstate` backend boundary, backs up existing state
when present, validates and saves a platform plan plus readable review.

Planning does not install charts, create namespaces or apply AWS resources.
Provider/backend reads and temporary S3 state locking occur normally. The
provider-backed checks must run in the normal terminal because of the agent
session's known provider/network limitations.

## Scope to review

| Resource | Intended behavior after an approved apply |
|---|---|
| Two namespaces | `agribridge-staging`, `agribridge-production` |
| External Secrets Helm release | Pinned controller and its IAM-enabled service account |
| F5 NGINX Helm release | Two controller replicas; public NLB, HTTPS 443 terminating with the issued ACM certificate |
| Two DNS records | Staging/production CNAMEs point to the NLB hostname |
| gp3 StorageClass | Encrypted EBS, WaitForFirstConsumer, expansion and Retain policy |
| kube-prometheus-stack Helm release | Prometheus/Grafana foundations with 10 GiB and 2 GiB PVCs |
| Fluent Bit Helm release | Forward logs through the scoped logging role |

The source describes nine managed Terraform resources, plus a deferred Service
data read. Helm and Kubernetes controllers create many underlying objects. In
particular, the NLB, its public IPv4 addresses and monitoring EBS volumes are
chargeable even though they are created indirectly rather than as explicit
AWS resources in this Terraform plan. Review the generated plan and an updated
cost estimate before approving apply. Retain storage continues to incur charges
after PVC deletion until the associated volumes are deliberately removed.

Application Helm releases, runtime SecretStores/ExternalSecrets from the
application chart, application database volumes, Argo CD and image publication
are not deployed by this plan. Monitoring foundations installed here will be
configured and demonstrated with application metrics and alerts in stage 7.

## GitOps ownership preparation

The previous platform module also created direct-CI deployment service accounts,
namespace roles/bindings, long-lived service-account tokens and Secrets Manager
`/deploy` secrets. Those old names remain scheduled for deletion. The module and
entry point now expose `enable_legacy_pipeline`, default false; the planning
command explicitly supplies false. All six legacy resource groups are gated
together. This fresh rebuild creates no direct-CI deployment credentials.

An existing deployment retaining those resources must explicitly enable the
flag before planning against its owning state, or Terraform could propose
deletion. Review every action rather than applying this change blindly to an
older state. The current rebuild uses a newly recreated backend bucket.

The existing repository workflow still contains direct Helm deployment logic.
No commit, push or workflow dispatch is being performed. Stage 6 will replace
that release path and install Argo CD after the source revision is reviewed
and published with approval.

## Local verification

Terraform formatting, shell syntax and whitespace checks passed. Eight isolated
command-stub scenarios passed: fresh state, existing state, wrong AWS account,
wrong cluster, services drift, services planning failure, denied state listing
and failed state backup. They verified that no platform plan runs after a failed
prerequisite and no apply/import/destroy is invoked. The local kubeconfig context
and API server match the expected cluster; credentials were not displayed.

Obtain the saved plan summary next; no platform apply has occurred.

## Saved plan reviewed — 2 November 2026, 13:35 UTC

Bernard supplied the complete successful planner transcript. Existing nodes and
core controllers passed readiness, the services plan reported No changes,
initialization succeeded and Terraform validation passed with AWS v6.71.0,
Kubernetes v2.38.0 and Helm v3.3.0.

- Saved plan: `.runtime/platform-20261102T133529Z-70457.tfplan`.
- Readable review: `.runtime/platform-20261102T133529Z-70457.txt`.
- SHA-256: `1cdbd71a3b5b4325332125eb5c51e7cc6cf2df08240aa12c4681cb9a420dcee5`.
- Summary: **9 additions, 0 changes, 0 deletions**; the ingress Service data
  source is read during apply after its Helm release is installed.

The embedded Terraform source files match current platform/module files. Runtime
inputs match account `237258628535`, zone `Z098670523YNOQ1LDBYDG` and the verified
ISSUED ACM certificate `af2e5092-e3e6-4438-a04c-bc586f3671a3`. The saved services
check also confirms No changes. Legacy pipeline resources are disabled; the nine
resource addresses match the scope table exactly, with no direct-CI credentials.

The ingress values request HTTPS 443 at the NLB, forward decrypted TCP to NGINX
HTTP port 80, use instance targets and the explicit AWS load balancer class, and
run two ingress replicas. Monitoring requests 10 GiB for Prometheus and 2 GiB for
Grafana. The StorageClass uses encrypted gp3 and Retain, and Fluent Bit uses the
scoped workload IAM role and existing 14-day CloudWatch destination.

### Estimated incremental baseline

| Component | Calculation | Approximate daily cost |
|---|---|---|
| NLB hourly charge | $0.0225 × 24 | $0.54 |
| Expected NLB public IPv4 | Two zones × $0.005 × 24 | $0.24 |
| Monitoring gp3 | 12 GiB × $0.08/month ÷ 30 | $0.032 |
| Platform subtotal | Rounded from $0.812/day | **$0.81/day** |

The two-address assumption follows the two public cluster subnets; verify the
actual NLB mappings and IP count after creation. Load-balancer capacity adds
$0.006 per NLCU-hour at the public us-east-1 rate. Traffic, cross-zone transfer
where applicable, CloudWatch logs, S3 backup usage, DNS queries and taxes are
additional. These are estimates, not a bill cap or an all-account total.
Combined with the previously reviewed cluster subtotal, cluster and platform
baseline is approximately $4.53/day before the separate stored-secret,
hosted-zone and usage charges. Application database storage is still excluded.

Read-only AWS Price List queries on 2 November confirmed NLB $0.0225/hour and
gp3 $0.08/GB-month. Official pricing pages confirm
[NLB capacity pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) and
[public IPv4 pricing](https://aws.amazon.com/vpc/pricing/).

### Apply decision

Bernard approved this artifact by executing the following exact apply from the
normal terminal. It is retained as a record; do not repeat the creation plan now:

```sh
terraform -chdir=terraform/platform apply -input=false \
  "$PWD/.runtime/platform-20261102T133529Z-70457.tfplan"
```

Saved inputs are included in the plan; no extra variable file is needed. Review
a different artifact separately if the plan or configuration changes. Applying
this stage starts the additional NLB and monitoring storage charges. It installs
platform foundations; it does not make the application or Argo CD live.

After completion, verify Helm release health, controller/webhook readiness,
expected NLB listener and certificate, DNS CNAMEs, monitoring PVC binding and
encrypted EBS volume quantities. Inspect actual created resources and a refreshed
platform plan before continuing to application and GitOps setup.

## Initial post-apply verification

All four Helm resources completed in the supplied apply transcript. Read-only
AWS checks confirm the expected two-zone NLB, TLS 443 listener/certificate, TCP
target group and both DNS CNAMEs. The actual monitoring disks are encrypted,
in-use gp3 volumes: Grafana 2 GiB and Prometheus 10 GiB, matching the estimate.
The first NLB read reported provisioning and registration-in-progress for both
workers. A subsequent read confirmed **active** NLB state and **healthy** target
health for both worker instance IDs. The AWS-side load-balancer gate has passed;
an end-to-end application response remains a later check after app deployment.

From the project root in the normal terminal, collect the remaining checks:

```sh
export KUBECONFIG="$PWD/.runtime/kubeconfig"
helm list -A
kubectl get pods -A
kubectl get pvc -n monitoring
terraform -chdir=terraform/platform plan -input=false -detailed-exitcode \
  -var-file=../../.runtime/platform.tfvars.json
```

Expect all four named Helm releases deployed, the platform workloads Ready, both
monitoring PVCs Bound and a No changes Terraform result. Completed installation
hook jobs can appear as Completed rather than Running. Do not display Kubernetes
Secret data or Grafana administrator credentials in shared output. The listed
application URLs are infrastructure outputs; no application release exists yet.
