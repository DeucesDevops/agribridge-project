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
| `tempo` | grafana/tempo | 1.24.4 | `tempo-values.yaml` |
| `monitoring` | prometheus-community/kube-prometheus-stack | 93.3.1 | `prometheus-values.yaml` plus the Grafana Ingress |
| `promtail` | grafana/promtail | 6.17.1 | `promtail-values.yaml` |

`storage-class.yaml` is the `gp3` class. Terraform reads that file and creates
it. The EBS CSI driver from kOps provisions the volumes.

Grafana is on the same Application Load Balancer as the app, at
`https://grafana.<zone>`. Anonymous access is off and sign-up is off. The
admin password is the Secrets Manager secret `agribridge/grafana`:

```sh
aws secretsmanager get-secret-value --secret-id agribridge/grafana \
  --query SecretString --output text
```

The user is `admin`. Prometheus, Loki and Tempo are already Grafana
datasources. The application chart publishes a ServiceMonitor for the API.
The API does not send traces, so Tempo stays empty until a tracer is added.

Workers are `t3.large`, one in each of two zones. If pods stay Pending, raise
`maxSize` on the node instance groups in `kops/cluster.yaml`, run
`./scripts/render-kops-terraform.sh`, then
`terraform apply -var install_platform=true`.
