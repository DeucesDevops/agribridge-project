# Verification — 30 October 2026

Deployment is incomplete. This file distinguishes observed resources, checks that
ran, and acceptance work that still needs a live cluster connection.

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
| Ingress | No ELBv2 load balancers existed; public application access is not ready |
| Logs | `/agribridge/containers` exists; no log streams at inspection |

## Repairs

- Corrected the audience in the four existing external-secrets, logging and backup
  IAM trust policies from `sts.amazonaws.com` to `amazonaws.com`, matching the
  kOps OIDC provider and pod identity webhook. Service-account subject restrictions
  remain specific to each role. The Terraform source now matches the repair.
- Added a cluster controller/webhook readiness gate before platform installation.
  The previous platform log reported `mservice.elbv2.k8s.aws` connection refused;
  later read-only controller logs showed it starting, but readiness has not been
  verified through the Kubernetes API in this session.
- Increased External Secrets installation timeout to 900 seconds. Its previous
  Helm install timed out; later logs show the controllers and webhook starting.
- Made monitoring depend explicitly on its StorageClass.
- Set the frontend pod's UID/GID and volume group to 101 so the non-root Nginx
  entrypoint can render runtime configuration into its emptyDir mounts while
  keeping the image filesystem read-only.
- Fixed deployment version verification to compare `/version.imageTag` against
  the requested tag argument, rather than the container's own `IMAGE_TAG` value.
- Switched image publication to the existing `macroni607` Docker Hub account using
  the prior workflow's `DOCKERHUB_TOKEN` secret. Both AWS SSM deployment handoffs
  now point to Docker Hub. Builds are separated from AWS-authenticated deployment;
  the same release tag is promoted to both environments. The token has not been
  read or printed. New credential authentication still needs a publish run.
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
prefix present in the working tree; successful role assumption still needs a new run.

## Remaining live acceptance

1. Review the first migration plan for each entry point, then run
   `bash scripts/resume-platform.sh` from an authenticated workstation with
   Kubernetes/network access. It refreshes service state and resumes platform
   Terraform without replacing the cluster. Confirm a second plan has no changes.
2. Run the delivery workflow from the branch containing this layout. Confirm AWS
   OIDC login, image publication, staging and production with identical image tags.
3. Confirm ExternalSecrets are Ready, PostgreSQL claims are Bound, HTTPS routing
   and staging login work, and the live API reports the expected commit/tag.
4. Exercise cache degradation, PostgreSQL persistence, Helm rollback, metrics and
   CloudWatch log delivery. Run a backup and an isolated restore drill.

Do not label the application production-ready until these checks have evidence.
