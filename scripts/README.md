# Automation scripts

Run commands from the project root. `make help` lists the common entry points.

| Task | Script | Used by |
|------|--------|---------|
| Plan bootstrap without applying AWS changes | `plan-bootstrap.sh` | `make plan-bootstrap` |
| Prepare kOps metadata and a cluster plan without applying nodes | `plan-cluster.sh` | `make plan-cluster` |
| Plan AWS services without applying or restoring secrets | `plan-services.sh` | `make plan-services` |
| Check services drift and plan Kubernetes platform foundations | `plan-platform.sh` | `make plan-platform` |
| Provision all infrastructure in order | `provision.sh` | `make provision` |
| Finish services/platform on an existing cluster | `resume-platform.sh` | `make resume` |
| Legacy direct Helm deployment | `deploy.sh` | Retired in favor of Argo CD |
| Prepare Argo CD controller plan | `plan-argocd.sh` | `make plan-argocd` |
| Generate non-secret GitOps runtime references | `prepare-gitops.sh`, `render-gitops-values.py` | Operator planning |
| Record, stage, promote and commit immutable image releases | `gitops-release.py` | Reviewed GitHub Actions workflow |
| Check public HTTPS and expected release identity | `wait-release.py` | CI deployment gates |
| Install Argo CD project/application definitions | `helm/argocd-bootstrap` | Terraform, after the controller's CRDs exist |
| Verify live secret delivery, migrations and staging login | `verify-application.sh` | Operator after deployment |
| Check GitHub access and credential names | `check-delivery-access.sh` | `make check-delivery` |
| Validate release safety and Helm renders | `test-gitops.py` | `make test-gitops` and CI |
| Inspect a flat Kubernetes render | `render-manifests.sh` | Operator |
| Verify isolated local containers, integration, persistence and cache failure | `verify-local.sh` | `make local-verify` |
| Check local Redis/DB restart behavior | `local-resilience.sh` | Operator, Compose only |
| Restore a backup into isolated temporary storage | `restore-drill.sh` | Operator |
| Wait for controllers and webhook endpoints | `wait-platform.sh` | Provisioning scripts |
| Prepare generated cluster Terraform as a module | `prepare-kops-module.py` | Provisioning script |
| Apply the generated bootstrap webhook fix | `patch-kops-bootstrap.py` | Provisioning script |
| Summarize JUnit results | `test-summary.py` | GitHub Actions |

The last four are internal helpers. During the staged rebuild, use the separate
planning commands and review each saved plan before applying it. `make provision`
and `make resume` automatically apply multiple stages and must not be used for
this staged review. The delivery workflow still requires the later GitOps handover.
