# Platform

Helm values for the cluster add-ons live in this directory. Terraform installs
the releases from `terraform/modules/platform` on
`terraform apply -var install_platform=true`.

| File | Used by |
|---|---|
| `argocd-values.yaml` | Argo CD |
| `monitoring-values.yaml` | kube-prometheus-stack, Loki, and Promtail |
| `external-secrets/values.yaml` | External Secrets operator |
| `external-secrets/secret-store.yaml` | Production SecretStore shape. The application chart renders the live object |
| `storage-class.yaml` | gp3 StorageClass |

See [terraform/modules/platform/README.md](../terraform/modules/platform/README.md).
