# Focused helpers

Run Terraform and kubectl directly using the reproduction and operations guides.
GitHub Actions runs application CI/CD. There are no stage-specific provision,
plan-bundle, cluster-session or operations wrappers.

| Helper | Responsibility | Caller |
|---|---|---|
| `prepare-cluster.py` | Render narrow API CIDRs, verify delegation, generate kOps Terraform and preserve its bootstrap compatibility fix; wait for controllers | Administrator terminal |
| `release.py` | Validate build identity, refresh non-secret runtime references and select/promote immutable digests | Terminal configuration and delivery CI |
| `smoke-test.py` | Verify HTTPS, build identity and optional runtime secret/migration/login checks | Delivery CI and administrator terminal |
| `check-resilience.py` | Deliberately restart staging cache/database pods and verify recovery and persistent data | Administrator terminal, staging only |
| `verify-local.sh` | Disposable Compose stack, integration tests, cache degradation and persistence | `make local-verify` |

`tests/` checks release contracts, Helm rendering, cluster preparation and blocking
CI gates offline. `requirements.txt` pins the Python dependency. Reusable delivery
actions cover Node setup, Helm rendering and GitOps promotion. `.github/ci/`
contains focused image, ingress and scan-result assertions only.

Backups are a Helm-defined CronJob; isolated restore verification is a Helm-defined
Job. Use the direct commands in [OPERATIONS.md](../docs/OPERATIONS.md).
