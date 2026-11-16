# Verification

## 16 November 2026 — course-style simplification

Reviewed the authenticated Udemy curriculum and its public QA workflow. The
AgriBridge security/build/promotion flow already followed the same stages.
Infrastructure and operations now use direct terminal commands; their workflows,
runner setup and task/bundle wrappers have been removed. Existing Terraform
state keys, resource addresses, Helm workloads and Argo CD ownership are retained.

| Offline check | Result |
|---|---|
| Cluster preparation, release, restore isolation, Helm rendering and CI gates | 28 tests passed |
| SonarQube coverage-report preparation | 4 tests passed |
| API unit tests and coverage | 42 tests passed |
| Frontend unit tests and coverage | 15 tests passed |
| API/frontend lint | Passed |
| Frontend production build | Passed |
| Terraform formatting, Helm lint, Bash syntax | Passed |
| Local Markdown links | Passed |
| Terraform provider schema validation on workstation | Blocked: local AWS provider plugin could not start under this session |

These checks do not establish a running cloud environment, successful live
SonarQube analysis or fresh vulnerability scan results. Full scans, container
acceptance and provider validation must pass on the exact PR commit in Actions
before merging. Do not use an older green commit as evidence for a new head.

## DNS and AWS inspection

Namecheap's four `agribridge` NS records match Route 53 zone
`Z098670523YNOQ1LDBYDG`; no registrar change was necessary. Only the `kops`
management instance was running in us-east-1 during the initial inspection.
The child zone had no staging/production application routing records. Retained
Terraform state still describes earlier resources, so a refreshed plan and live
verification are required before restoration. See [DNS.md](DNS.md).

## Live acceptance still required

1. Inspect the PR's full validation, security scan and container results.
2. Review current remote-state Terraform plans and apply intended changes.
3. Verify both Argo CD Applications, HTTPS readiness and matching image digests.
4. Run backups, isolated restores and the deliberate staging resilience test.
5. Record actual run URLs and non-secret receipts under `docs/evidence/`.

Historical [operational acceptance](evidence/ACCEPTANCE.md) and earlier reviews
remain evidence of previous demonstrations, not current service uptime.
