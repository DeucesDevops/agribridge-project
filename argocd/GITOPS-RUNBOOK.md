# Stage 6 — CI/CD and Argo CD

Status on 2 November 2026: source prepared locally; thirteen release/render checks
passed. The full changed-image local acceptance, pinned upstream chart render and
GitHub access/credential-name preflight also passed. The saved two-addition
controller/bootstrap plan is reviewed in [PLAN-REVIEW.md](PLAN-REVIEW.md).
The controller and bootstrap apply completed with two additions. All reported
Argo pods are ready and a refreshed platform plan reports no changes. Reviewed
source publication, a successful live workflow and application acceptance
remain pending. Stage 5's platform Helm
releases, workloads, monitoring PVCs and no-change plan have passed.

## Ownership

| Owner | Responsibility |
|---|---|
| Terraform | AWS/platform foundations, Argo CD controller and bootstrap Helm release |
| GitHub Actions | Checks, exact-image verification, scanning, Docker Hub publication and image-version commits |
| Argo CD | Reconcile the application Helm chart in staging and production from main |
| External Secrets | Deliver runtime Secrets from the two Secrets Manager JSON entries |

The chart is rendered by Argo CD; application resources are not separate Helm
CLI releases. Use Argo CD and Kubernetes for application status. The former
direct Helm deployment script is retired.

## Pipeline behavior

The four jobs are checks → publish → staging → production. Pull requests run
checks. Main application-source pushes and manual dispatch on main can release.
Image-only and documentation commits do not start another build.

Checks cover both applications' lint with zero warnings, dependency audits, API
unit coverage, real PostgreSQL integration tests, frontend tests/build, Terraform,
shell syntax and GitOps/Helm rendering. Publish builds with commit/run/attempt
identity, verifies the exact Compose images, same-origin login, readiness and
build identity, then scans both images with Trivy 0.69.3. Fixable HIGH/CRITICAL
image vulnerabilities block publication.

Actual published digests are recorded in a release artifact. Staging commits
these digests to staging-values.yaml. Argo CD deploys them, and public HTTPS,
readiness and API build identity must pass before production runs. Production
copies the same digests into production-values.yaml without rebuilding.
A configured production-environment required-reviewer rule pauses promotion.
Without that rule, promotion follows staging automatically.

Staging/production jobs have contents: write for their fixed image-values files.
They use GITHUB_TOKEN and ordinary fast-forward pushes, stop on conflicts and
stop if application/chart/delivery source changed since the build. No AWS keys,
AWS deployment role or Kubernetes kubeconfig is needed in CI.

## Runtime handoff

make prepare-gitops reads Terraform-published non-secret SSM deployment metadata.
The renderer validates account/environment identities and generates hostname,
region, image repository, secret ARN and backup bucket/role references, preserving
existing image selections. No secret VALUE is fetched. The actual PGPASSWORD,
JWT_SECRET and SEED_PASSWORD stay in Secrets Manager.

Initial image-values files set releaseEnabled: false, so bootstrap renders no
application workloads. CI enables staging with published digests; promotion
enables production. Enabled GitOps releases require valid digests. The earlier
ExternalSecret sync wave waits for runtime delivery before workloads. Staging's
idempotent seed Job uses Helm post-install/post-upgrade hooks, mapped to Argo CD
PostSync. Production is deliberately unseeded.

Terraform's argocd-bootstrap Helm release installs the reviewed project and both
Application files after controller CRD creation. The AppProject allows this repo
and the two Terraform-created namespaces. Applications track main, self-heal and
do not automatically prune. Explicit application/bootstrap deletion uses a
finalizer to cascade workloads; retained database PVC/EBS data needs separate
deliberate cleanup.

## First setup

1. Activate Python and verify the changed images in the normal terminal:

   ```sh
   source .runtime/python-venv/bin/activate
   make local-verify
   ```

   The new frontend /readyz and /version routes need this rerun. It also checks
   authentication, real integration tests, persistence and cache degradation.
   The agent's restricted session cannot access Docker's socket.

2. Run make check-delivery. It reads authentication, repository permissions,
   Actions availability, credential NAMES, main protection and production rule
   metadata. Use gh auth login if authentication is missing. Set DOCKERHUB_TOKEN
   interactively as a repository secret if missing; never paste it into source
   or conversation output. Application Docker Hub repositories must be public.
   Protected main requires a reviewed bot-push policy or PR release design;
   this check stops instead of changing protection.

   The 2 November preflight passed: GitHub identity/access, Actions availability
   and the DOCKERHUB_TOKEN secret NAME are confirmed; main is not protected.
   Production currently has no required-reviewer rule, so the prepared workflow
   will promote automatically after staging passes. The token's actual Docker
   Hub authentication will be verified by CI rather than reading its value here.

3. Run make plan-argocd. It regenerates runtime references, renders pinned chart
   10.11.6 (Argo CD v3.5.6), verifies private ClusterIP services, checks core
   readiness and services drift, then saves a platform plan with enable_argocd.
   It applies nothing. Expect two additional Helm resources: argocd and
   argocd-bootstrap. Review the real plan before approving apply.
   Controller renders can contain generated Secret objects; they and Helm's
   preparation cache stay private under .runtime. The local render confirmed
   private services and no additional ingress, PVC or volume claim template.
   Later plans preserve the installed controller's enable flag.

4. After approving/applying that exact plan, check controller workloads and a
   fresh no-change platform plan. The UI stays private; no new public load
   balancer is requested. Before new source is published, Applications may report
   the old repository's missing chart path. The reviewed source push resolves
   this bootstrap gap; do not repair the Applications by hand.

5. Review the complete intended source diff, including earlier folder moves and
   deletions, and obtain explicit commit/push approval. Include workflow, scripts,
   Terraform, both Helm charts, application source, Argo configuration and relevant
   docs. Exclude .runtime, .env, state/plans, kubeconfig, credentials, dependencies
   and test reports. Review optional design/image artifacts separately.
   A source push starts CI and ultimately both deployments; publish a coherent
   source change rather than a partial folder move.

6. Watch the first real workflow and Argo CD Applications. CI release commits
   advance main. Once local changes are committed and ready, fetch those commits
   with git pull --ff-only before live release verification:

   ```sh
   export KUBECONFIG="$PWD/.runtime/kubeconfig"
   kubectl -n argocd get applications
   bash scripts/verify-application.sh staging
   bash scripts/verify-application.sh production
   ```

   These checks verify ExternalSecret readiness, PVC metadata, rollouts, migration
   filenames, public HTTPS and exact build identity. Staging login and secure
   httpOnly session cookies are tested with credentials only inside the running
   API pod. Secret values and cookies are never printed. Production has no demo
   login. No live CI/CD success is claimed before this actually passes.

## Cost and evidence

Argo CD uses existing cluster nodes/private services. No extra EC2 group or
load balancer is planned for it. Application deployment requests one 20 GiB gp3
database volume per environment: 40 GiB, about $3.20/month at the verified
us-east-1 $0.08/GB-month rate, before usage/taxes. Existing cluster/platform, DNS,
secrets and logging charges continue. Verify actual scheduling, encryption and
quantities after sync.

Finish stage 6 with a successful live workflow, synced/healthy applications,
runtime-secret/migration/routing checks, identical staging/production digests and
Git-based rollback evidence. With self-heal enabled, rollback means reverting the
environment image selection in Git. Stage 7 demonstrates metrics/logs/alerts;
stage 8 completes restore, persistence and final assessment evidence.

References: [Helm integration](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/),
[sync waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/),
[pinned chart](https://github.com/argoproj/argo-helm/tree/argo-cd-10.11.6/charts/argo-cd),
[EBS pricing](https://aws.amazon.com/ebs/pricing/).
