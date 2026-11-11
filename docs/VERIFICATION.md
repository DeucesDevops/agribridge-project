# Verification

## Scope

This guide records the checks for the cloud automation/GitOps refactor on `dev`.
AWS application infrastructure remains offline. The implementation has not been
verified by applying or destroying cloud resources during this review.

The earlier AWS demonstration includes completed cache-resilience, database
persistence and isolated staging/production restore receipts. Their sanitized
[operational acceptance summary](evidence/ACCEPTANCE.md) records those results
separately from validation of the refactored workflows.

## Local checks — 7 November 2026

| Check | Result and scope |
|---|---|
| Automation, release and Helm-render tests | 24 tests passed |
| SonarQube coverage preparation | 4 tests passed; this validates report handling, not a server analysis |
| Local verification script | Bash syntax passed; full Docker execution requires engine access |
| Terraform formatting | Passed |
| Application Helm chart | Lint passed; both environment renders are exercised by the tests |
| Workflow lint | Passed actionlint with ShellCheck enabled, matching CI |
| Markdown links | Passed; no missing local targets in the current guides |

The workflow-lint fix groups repeated output redirects in the delivery and
infrastructure workflows. ShellCheck remains enabled; no warning is suppressed.

## GitHub Actions acceptance

Use [PR #2 checks](https://github.com/DeucesDevops/agribridge-project/pull/2/checks)
to inspect the latest result for the exact commit being considered for merge.
Earlier green results on another commit do not validate a new branch head.

The checks job must complete all of the following:

- Reproducible dependency installation, linting and dependency audit.
- API unit/coverage tests and integration tests against real PostgreSQL.
- Frontend unit/coverage tests and the production build.
- Coverage-path preparation, automation/release tests and Helm lint/render checks.
- NGINX/NLB rendering, actionlint/ShellCheck, Bash syntax and Terraform checks.
- Test-report and coverage artifact publication.

Generated cluster Terraform validation is intentionally deferred in a clean CI
checkout until kOps generates that configuration. Terraform formatting alone is
not a provider-schema validation or an AWS plan.

PR runs intentionally skip image publication and deployment. SonarQube is also
skipped on PRs under the current Community Build integration. A passing PR does
not demonstrate a live SonarQube gate, an image scan/publication or an Argo CD sync.

## Security finding

Resolve the GitGuardian finding attached to the PR independently of application
CI. The scanner examines commit history as well as the current source tree; simply
deleting a value from the latest tree may not resolve a historical finding.
Do not dismiss a finding without checking its source and credential validity.
Do not put detected values in this report, commit messages or pipeline logs.

The finding in commit `2cb700c47de8aca96e93cb8788175f0d674b883b`, historical
`compose.yaml` line 24, was traced to a required `REDIS_PASSWORD` environment
interpolation and its setup error message. That line contains no literal password
or fallback credential. Record this as a false positive in GitGuardian after
signing in; keep repository secret scanning enabled.

## Live checks still required

After separately configuring the runner, OIDC roles and protected environments:

1. Review and apply the infrastructure stages against the existing state keys.
2. Complete a delivery run through staging and production with the same digests.
3. Run operational acceptance in both environments.
4. Verify a backup, isolated restore test and staging resilience demonstration.

Record new workflow URLs and non-secret results under `docs/evidence/`. Earlier
deployment evidence is historical and does not establish current service uptime.
