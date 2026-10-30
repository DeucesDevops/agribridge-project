# Verification — 30 October 2026

The core deployment is live in staging and production. This file distinguishes
verified deployment evidence from operational acceptance checks still outstanding.

## AWS inventory

Inspected account `237258628535`, region `us-east-1`, using AWS APIs.

| Component | Observed evidence |
|-----------|-------------------|
| kOps compute | Three running t3.medium instances: one control plane and two workers, tagged `k8s.agribridge.deuces.dev` |
| Existing EC2 hosts | Two unrelated pre-existing t2.small hosts were stopped; left untouched |
| State/discovery | `agribridge-tfstate-237258628535`, `agribridge-oidc-237258628535`, and `kops-state-607` exist |
| Backups | `agribridge-backups-237258628535` exists; backup/restore not yet validated |
| ECR | `agribridge-api` and `agribridge-web` exist; both had zero images at inspection |
| Secrets | Separate staging/production runtime and deploy secret entries exist; values were not printed |
| TLS/DNS | Public `agribridge.deuces.dev` zone exists; apex/wildcard ACM certificate is ISSUED |
| Ingress | After the workstation apply, `agribridge-ingress` NLB is active with both worker targets healthy, using TLS 443 and the existing ACM certificate |
| Logs | CloudWatch is receiving application, database, cache and staging seed logs in `/agribridge/containers` |

## Repairs

- Corrected the audience in the four existing external-secrets, logging and backup
  IAM trust policies from `sts.amazonaws.com` to `amazonaws.com`, matching the
  kOps OIDC provider and pod identity webhook. Service-account subject restrictions
  remain specific to each role. The Terraform source now matches the repair.
- Added a cluster controller/webhook readiness gate before platform installation.
  The previous platform log reported `mservice.elbv2.k8s.aws` connection refused;
  later read-only controller logs showed it starting. Subsequent successful
  platform/application deployment provides the later evidence described below.
- Increased External Secrets installation timeout to 900 seconds. Its previous
  Helm install timed out; later logs show the controllers and webhook starting.
- Made monitoring depend explicitly on its StorageClass.
- Set the frontend pod's UID/GID and volume group to 101 so the non-root Nginx
  entrypoint can render runtime configuration into its emptyDir mounts while
  keeping the image filesystem read-only.
- Replaced the failed Traefik configuration with maintained F5 NGINX OSS chart
  2.8.0/controller 5.7.0. Its Service requests one internet-facing AWS NLB using
  instance targets and the existing ACM certificate; only TLS port 443 is public,
  forwarding to NGINX HTTP port 80. Both environment Ingresses select class `nginx`.
  The pinned upstream chart was fetched for an offline render check: controller
  and Service names, replica count, status-reporting target, load balancer class
  and listener/target ports all passed. Local rendering skipped upstream schema
  validation because its schema references an external URL blocked in this
  session; CI runs the normal schema-aware chart render.
- Fixed deployment version verification to compare `/version.imageTag` against
  the requested tag argument, rather than the container's own `IMAGE_TAG` value.
- Switched image publication to the existing `macroni607` Docker Hub account using
  the prior workflow's `DOCKERHUB_TOKEN` secret. Both AWS SSM deployment handoffs
  now point to Docker Hub. Builds are separated from AWS-authenticated deployment;
  the same release tag is promoted to both environments. The token has not been
  read or printed. Docker Hub authentication and both image pushes passed in the delivery run below.
  Existing empty ECR repositories are retained rather than destroyed.
- Moved source to the agreed folder layout and updated Compose, workflow, scripts,
  Terraform file references, documentation, and monitoring values.
- Refactored Terraform into four thin entry points and ten child modules. Static
  migration checks account for all 141 original resource blocks: 13 bootstrap,
  91 cluster, 24 services and 13 platform. Every move points to an existing
  module resource; all child variable references are declared, and child modules
  have no provider configuration or backend. Local module installation with
  `terraform get` passed for all four entry points. This does not replace a live
  Terraform plan.

## Checks executed

| Check | Result |
|-------|--------|
| API zero-warning lint | Passed |
| API unit tests and coverage | 42 tests passed; statements 98.36%, branches 95.23%, functions/lines 100% |
| Frontend zero-warning lint | Passed after folder move |
| Frontend tests and coverage | 15 tests passed; statements/functions/lines 100%, branches 96.96% |
| Frontend production build | Passed after folder move; largest JS chunk 141.74 kB |
| Helm lint | Passed at `helm/agribridge` |
| Terraform format and shell syntax | Passed |
| Deployment verifier with stubbed CLIs | Accepted the requested baked tag despite a different caller environment; rejected a stale tag |
| Platform readiness gate with stubbed CLIs | Accepted ready endpoints; rejected empty webhook endpoints |
| Local Terraform provider validation | Blocked: provider subprocesses could not complete their plugin handshake in this session |
| Direct kubectl and Docker | Blocked by session permissions: Kubernetes connection `operation not permitted`, Docker socket `permission denied` |

The existing GitHub run [41051685155](https://github.com/DeucesDevops/agribridge-project/actions/runs/41051685155)
at commit `f510b2f` passed its checks job, including real PostgreSQL integration
tests and dependency audits. Its staging job failed at AWS OIDC role assumption;
production was skipped. That run predates these changes and does not validate the
new layout. The live pipeline role already carries the repository-ID-based subject
prefix present in the working tree. A later successful delivery run verified role assumption in both environments.

The modular/Docker Hub revision at `2dc75ad` passed all checks in
[41055667305](https://github.com/DeucesDevops/agribridge-project/actions/runs/41055667305),
including full validation of all four Terraform entry points and the PostgreSQL
integration suite. This precedes the NGINX switch, which adds upstream chart rendering
to CI. Pull-request checks intentionally skip publishing and deployment.

A fresh AWS read before the NGINX switch confirmed three running cluster instances,
two appropriately tagged public subnets and zero ELBv2 load balancers. A direct
Kubernetes API request still failed with `operation not permitted`. At that point
the NLB and app DNS records were configured only in source; later AWS and delivery
verification below supersedes that intermediate status.

Subsequent workstation execution on 30 October created the NLB at 12:51 UTC and
both Route 53 CNAME records. AWS APIs then confirmed NLB state `active` and two
healthy instance targets on NodePort 30922. Monitoring finished updating, but the
platform apply failed because the existing External Secrets Helm release was still
in use. The resource now enables `upgrade_install` for a retry using the same pinned
chart and role. At that point recovery and delivery were pending; the successful
delivery below subsequently verified application deployment.

## Successful deployment evidence

[Delivery run 41059971340](https://github.com/DeucesDevops/agribridge-project/actions/runs/41059971340)
completed successfully at commit `0984fae3f5db513447bac83af62d5bc3c2d51bba`.
All four jobs passed: checks, Docker Hub publication, staging and production.
Both Helm releases reported deployed revision 1. API version output in both jobs
reported the same commit and image tag:
`0984fae3f5db513447bac83af62d5bc3c2d51bba-41059971340-1`.

| Verification | Result |
|--------------|--------|
| Staging HTTPS | AgriBridge sign-in page verified in the browser |
| Production HTTPS | AgriBridge sign-in page verified in the browser |
| API identity and readiness | Verified by both successful deployment jobs |
| Docker Hub API image | Published digest `sha256:db45d2340f4f8c8b47b84c91f34468a6a882ef322024eeadfcf5995c18fdcb8c` |
| Docker Hub frontend image | Published digest `sha256:017523fd720cb20f16c5488e013159d7d70dc7b4ef47f0e3db7899efa6186d8c` |
| Log collection | CloudWatch streams present for both environments |
| Demo seeding | Staging seed hook completed during its successful Helm release; production remains unseeded |

The later folder simplification preserves module labels, resource names, provider
aliases, backend keys and release configuration. It requires no live infrastructure
apply; CI validates the relocated source paths.

## Folder and guide verification

- Compared the relocated Terraform against a source snapshot taken immediately
  before simplification. All 141 managed resource blocks, 141 migration blocks,
  data blocks, module labels, provider configurations, variables and existing
  outputs are preserved after accounting for relative-path changes. Terraform
  requirements and backend settings are unchanged. The only new Terraform
  declarations expose the hosted-zone ID/name servers through bootstrap outputs.
- Installed local module references successfully from all four numbered stacks.
  Resolved all 52 Terraform file/template references and 26 local Markdown links.
- `make check` passed Terraform formatting, syntax checks for every shell script,
  and Helm lint. Workflow YAML parsed with the expected four jobs. Make targets
  were dry-run without provisioning or deploying live resources.
- Added the ordered 15-stage rebuild guide, per-stage future-chat prompts and a
  configuration checklist covering supplied inputs and generated handoffs. The
  original assessment remains in `docs/ASSESSMENT.md`.

Local static checks do not prove a no-drift cloud plan. Full provider validation
for the relocated roots runs in pull-request CI; live operational checks below
remain separate.

## Remaining operational acceptance

1. Confirm a fresh Terraform plan has no unintended infrastructure changes after
   reinitializing the numbered stack directories.
2. Exercise an authenticated staging order flow and confirm Prometheus targets and
   application metrics in the dashboards.
3. Verify cache degradation, database persistence, Helm rollback, a manual backup
   and an isolated restore drill.

These unexecuted checks are not implied by successful deployment. Do not describe
the system as production-ready until the required operational checks have evidence.
