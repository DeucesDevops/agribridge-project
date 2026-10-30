# Automation scripts

Run commands from the project root. `make help` lists the common entry points.

| Task | Script | Used by |
|------|--------|---------|
| Provision all infrastructure in order | `provision.sh` | `make provision` |
| Finish services/platform on an existing cluster | `resume-platform.sh` | `make resume` |
| Deploy an existing image release | `deploy.sh` | GitHub Actions |
| Inspect a flat Kubernetes render | `render-manifests.sh` | Operator |
| Check local Redis/DB restart behavior | `local-resilience.sh` | Operator, Compose only |
| Restore a backup into isolated temporary storage | `restore-drill.sh` | Operator |
| Wait for controllers and webhook endpoints | `wait-platform.sh` | Provisioning scripts |
| Prepare generated cluster Terraform as a module | `prepare-kops-module.py` | Provisioning script |
| Apply the generated bootstrap webhook fix | `patch-kops-bootstrap.py` | Provisioning script |
| Summarize JUnit results | `test-summary.py` | GitHub Actions |

The last four are internal helpers. You normally start with `make provision`,
`make resume`, or the delivery workflow.
