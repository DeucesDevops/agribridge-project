# Stage 6 rollback demonstration review

Status: approved and completed on 2 November 2026. Both verified releases passed
CI and live acceptance. Staging rolled back to the first release and was restored
to the second; production stayed on the second during the rollback. Both final
Argo Applications are Synced and Healthy. The scan-blocked images were not used.

## Approved procedure

1. Dispatch delivery.yaml on current main to produce a second release through
   the same checks, image acceptance, scan, staging and production gates. The
   current workflow automatically promotes to production after staging passes.
   This rebuild needs no application behavior or database schema change.
2. After the full run succeeds, record its source SHA, image tag and both
   published digests. Stop if source changed unexpectedly, a gate failed, or
   either environment does not serve that exact release.
3. Commit only staging's API/web image selections and release.gitSha back to
   the first verified release below. Use a normal fast-forward commit/ref update
   with an expected-head check. Keep all runtime metadata and production values
   unchanged. The argocd-only commit does not trigger another image build.
4. Wait for Argo CD to reconcile and for staging HTTPS readiness/version to
   report the first release again. Check the live staging Application health,
   workloads and application acceptance. Confirm production still serves the
   second release. Record both Git and runtime evidence.
5. Restore staging's second-release image selections in Git, verify readiness
   and identity again, and confirm both environments match. Keep both sets of
   published image digests for future recovery.

This demonstrates rollback between two actual immutable image builds. Because
the application code/schema need not change, it does not demonstrate recovery
from an incompatible migration or an intentional application defect. No database
rollback, PVC deletion, Terraform apply or manual Helm deployment is involved.
Argo CD remains the application owner throughout.

## First verified rollback target

- Source: eea3e3ba44aa53b095971f3f284c2bc7366644e0.
- Tag: eea3e3ba44aa53b095971f3f284c2bc7366644e0-41470632352-1.
- API: sha256:d2bbca13851383496914961fe1fad40ceea550f7054a91b5b6e2509d55aed584.
- Web: sha256:093248810263c826a3ceb73119279ef751302319695cc95d3f75c1c8974a2de4.

## Execution evidence

| Milestone | Evidence |
|---|---|
| Second release | [Workflow 41473944213](https://github.com/DeucesDevops/agribridge-project/actions/runs/41473944213), all four jobs passed |
| Second release in production | Commit 2198cb0e89cbf59ce45acb65662ade593482fc90 |
| Staging rollback | [Commit 12083b4](https://github.com/DeucesDevops/agribridge-project/commit/12083b434d919e717c9931d8dc28ca5c5c854f3a), only staging-values.yaml changed |
| Staging restore | [Commit e78bc34](https://github.com/DeucesDevops/agribridge-project/commit/e78bc34fc86dc956c11c1ba69730370ad043a97e), only staging-values.yaml changed |

The second release source/tag is
d4ecba9b46dc18e0a334d49e0f9c99faef29035c-41473944213-1. Its API digest is
sha256:9d359ed35c36069bfc0f8620c58f644ca73c7dd399ff573eef70f322aded6420;
web is sha256:ac4cb3a15a83e9f93d95dcffb22b30b405d3841ff98176c80fef520a3f213c60.

Independent HTTPS checks verified both sites on the second release before the
rollback. During rollback, six consecutive HTTPS readiness/frontend/version
observations from a running API pod verified staging on the first release and
production on the second. Direct client checks had intermittent DNS/timeouts;
these are retained as diagnostics and are not counted as successful observations.
Argo CD reported the rollback Synced/Healthy/Succeeded with the first image digests.
The full staging acceptance script passed during rollback, including migrations,
runtime secret checks, login and secure session cookies.

After restoration, both full environment acceptance scripts passed. Live Argo
status/history confirms the rollback and restore revisions in staging and no
rollback deployment in production. Both environments' ready Deployment replicas
equal their desired counts and both PostgreSQL StatefulSets are ready. The
original Bound 20 GiB PVC volume identities were unchanged:

- Staging: pvc-18abdf7d-190d-428a-8d82-621b52af1598.
- Production: pvc-3da7942f-00fe-4ecd-8215-6c64b172e815.

Raw non-secret receipts, Application history, HTTP observations and resource/PVC
metadata are retained privately in .runtime/rollback-demonstration/ and its JSON
receipt. This completes stage 6. Stage 7 demonstrates monitoring, logs and alerts;
backup/restore and final assessment evidence still need their later checks.

## Review boundary

The proposed dispatch deploys a second release to both environments. The rollback
and restore steps affect staging only, with ordinary rolling updates on existing
resources. No additional instance, load balancer or database volume is requested;
existing compute, registry, traffic and logging usage continues. Bernard approved
the additional live demonstration before dispatch and the Git image changes.
