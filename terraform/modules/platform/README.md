# Platform

Helm releases installed on the second apply, when the production root sets
`install_platform` true. kOps already installs the AWS Load Balancer
Controller, the EBS CSI driver, and the pod-identity webhook. This module does
not install a second copy of the load balancer controller.

| Release | Chart | Version | Values |
|---|---|---|---|
| `external-secrets` | external-secrets/external-secrets | 2.15.0 | IRSA role |
| `external-dns` | external-dns/external-dns | 1.23.0 | zone filter, `upsert-only`, IRSA role |
| `loki` | grafana/loki | 7.6.0 | `values/loki-values.yaml` |
| `monitoring` | prometheus-community/kube-prometheus-stack | 93.3.1 | `values/prometheus-values.yaml` plus the Grafana Ingress |
| `promtail` | grafana/promtail | 6.17.1 | `values/promtail-values.yaml` |
| `argocd` | argo/argo-cd | 10.18.2 | `values/argocd-values.yaml` plus the hostname and certificate |
| `agribridge-application` | `helm/agribridge-application` | chart in this repo | Application `agribridge`, after Argo CD |

`values/storage-class.yaml` is the `gp3` class. Terraform reads that file and
creates it. The EBS CSI driver from kOps provisions the volumes.

The production root passes `install_platform=true` on the second apply. That
flag stays true whenever these releases should remain. The default is false,
which omits this module for that run. Removing a release from this module
uninstalls it on the next apply that still has `install_platform=true`.

Grafana is on the same Application Load Balancer as the app, at
`grafana.<zone>`. Calico pod IPs are not routable from the VPC, so the Grafana
Service is a NodePort and the Ingress target type is `instance`. The Ingress
group is `agribridge`. Anonymous access and sign-up are off. The username and
password are the `admin_user` and `admin_password` keys in Secrets Manager
`agribridge/grafana`.

Argo CD is on the same load balancer. The Service is a NodePort, the target
type is `instance`, and TLS ends at the load balancer (`server.insecure`).
The username is `admin`. The password is generated into
`argocd-initial-admin-secret`. The Helm and Kubernetes providers are
configured in the production root. This module has no provider or backend
blocks.

Chart versions live in `main.tf`. The CI workflow reads the `argocd` version
from that file when it renders the Argo CD chart.
