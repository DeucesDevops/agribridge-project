# Argo CD GitOps

Terraform installs the Argo CD controller and `helm/argocd-bootstrap`, which creates
this folder's AppProject and both Application objects. Argo CD owns the application
resources rendered from `helm/agribridge`; Actions never directly Helm-installs the
application into these namespaces.

| File | Responsibility |
|---|---|
| `argocd-values.yaml` | Controller settings, including private service exposure |
| `project.yaml` | Allowed repository, namespaces and resource kinds |
| `*-application.yaml` | Chart path and ordered values files for each environment |
| `staging-values.yaml`, `production-values.yaml` | Terraform-derived runtime references and CI-selected release digests |

The services infrastructure job refreshes runtime references from Parameter Store
without changing image selections. Delivery records actual published digests,
updates staging in Git, waits for public release verification, then promotes the
same digests to production. Each environment retains its own runtime configuration.

AWS application infrastructure is currently offline. Historical installation and
rollback evidence is retained in [docs/evidence](../docs/evidence/). The refactored
cloud workflows require their own live validation before claiming success.

See the [GitOps runbook](GITOPS-RUNBOOK.md), [setup](../docs/CONFIGURATION.md) and
[operations](../docs/OPERATIONS.md). No runtime secret values belong here.
