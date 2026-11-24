# Platform add-ons

kOps installs the AWS Load Balancer Controller, the EBS CSI driver and the
pod-identity webhook as part of the cluster. Terraform installs the rest on
`terraform apply -var install_platform=true`, after
`kops export kubeconfig --admin`. The values files in this directory are the
inputs. Do not install these charts by hand.

| Release | Chart | Version | Values |
|---|---|---|---|
| `external-secrets` | external-secrets/external-secrets | 2.15.0 | IRSA role |
| `external-dns` | external-dns/external-dns | 1.23.0 | zone filter, `upsert-only`, IRSA role |
| `loki` | grafana/loki | 7.6.0 | `loki-values.yaml` |
| `monitoring` | prometheus-community/kube-prometheus-stack | 93.3.1 | `prometheus-values.yaml` plus the Grafana Ingress |
| `promtail` | grafana/promtail | 6.17.1 | `promtail-values.yaml` |
| `argocd` | argo/argo-cd | 10.18.2 | `argocd-values.yaml` plus the hostname and certificate |
| `agribridge-application` | `helm/agribridge-application` | chart in this repo | Application `agribridge`, after Argo CD |

`storage-class.yaml` is the `gp3` class. Terraform reads that file and creates
it. The EBS CSI driver from kOps provisions the volumes.

The second apply passes `install_platform=true`. That flag stays true whenever
these releases should remain. The default is false, which omits the module for
that run.

Grafana is on the same Application Load Balancer as the app, at
[https://grafana.agribridge.deuces.dev](https://grafana.agribridge.deuces.dev).
Calico pod IPs are not routable from the VPC, so the Grafana Service is a
NodePort and the Ingress annotation `alb.ingress.kubernetes.io/target-type`
is `instance`. The Ingress group is `agribridge`, the same group as the app,
so both hostnames share one load balancer. The app is
[https://production.agribridge.deuces.dev](https://production.agribridge.deuces.dev).
Anonymous access is off and sign-up is off. The username and password are the
`admin_user` and `admin_password` keys in Secrets Manager `agribridge/grafana`.
Read the secret on your machine. Do not paste the password into git, issues,
or chat.

Argo CD is on the same load balancer, at
[https://argocd.agribridge.deuces.dev](https://argocd.agribridge.deuces.dev).
The Service is a NodePort and the target type is `instance`, in the group
`agribridge`. TLS ends at the load balancer and the server is HTTP, which is
`server.insecure`. Dex and the notifications controller are off. The username
is `admin`. The password is generated into `argocd-initial-admin-secret`:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

Do not paste that password into git, issues, or chat. The release
`agribridge-application` creates the Application `agribridge` in the `argocd`
namespace. It syncs `helm/agribridge` from `main` with prune and selfHeal.
Image tags come from `values-production.yaml`. Terraform supplies the
hostname, region, certificate ARN, backup bucket and backup role as Helm
parameters. The GitHub repository is public, so Argo CD clones it without a
credential.

```sh
aws secretsmanager get-secret-value --secret-id agribridge/grafana \
  --query SecretString --output text
```

`admin_user` is `admin`. Prometheus and Loki are Grafana datasources.
Prometheus is not exposed on the load balancer. Use Grafana Explore, or:

```sh
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090
```

The application chart publishes a ServiceMonitor for the API at `/metrics`.
The load balancer health check for Grafana is `/api/health` on the Grafana
Service. That path belongs to Grafana. The app's `/healthz` is NGINX on the
web Service.

Distributed tracing is a later addition: OpenTelemetry in the API, plus Tempo
as the store. This directory does not ship a Tempo release or a Tempo
datasource.

Workers are `t3.large`, one in each of two zones. If pods stay Pending, raise
`maxSize` on the node instance groups in `kops/cluster.yaml`, run
`./scripts/render-kops-terraform.sh`, then
`terraform apply -var install_platform=true`.
