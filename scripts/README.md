# Focused helpers

GitHub Actions owns infrastructure sequencing, approvals, cloud authentication,
maintenance task selection and logs. These helpers contain logic worth testing
or reusing, rather than separate entry points for every stage.

| Helper | Responsibility | Caller |
|---|---|---|
| `prepare-cluster.py` | Render runner/VPN access CIDRs, generate kOps Terraform, preserve the provider/output contract and bootstrap webhook fix; wait for controllers | Infrastructure workflow |
| `release.py` | Refresh non-secret runtime references, record published digests, stage/promote releases and commit validated image selections | Infrastructure and delivery workflows |
| `smoke-test.py` | Verify public HTTPS and exact build identity; optional runtime secret/migration/login checks | Delivery and operations workflows |
| `check-resilience.py` | Restart staging cache/database pods and verify recovery and persistent data | Explicit staging-only operations task |
| `verify-local.sh` | Disposable Compose stack, integration tests, cache degradation and persistence | `make local-verify` |

`tests/` verifies release contracts, Helm rendering, cluster preparation and workflow
safety without AWS. `requirements.txt` pins the helpers' Python dependency.

The former stage-specific plan/provision/resume scripts and direct Helm deploy
wrapper have been retired. Restore verification is a Helm-defined Kubernetes Job;
backup scheduling is a Helm-defined CronJob. See [operations](../docs/OPERATIONS.md).
