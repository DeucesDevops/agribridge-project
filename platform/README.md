# Platform add-ons

Terraform installs these charts on `terraform apply -var install_platform=true`.
The values files in this directory are the inputs. Do not install the charts
by hand.

| Release | Chart | Version | Values |
|---|---|---|---|
| `aws-load-balancer-controller` | eks/aws-load-balancer-controller | 1.17.1 | set by Terraform: cluster name, VPC, region, IRSA role |
| `external-secrets` | external-secrets/external-secrets | 2.15.0 | IRSA role |
| `external-dns` | external-dns/external-dns | 1.23.0 | zone filter, `upsert-only`, IRSA role |
| `loki` | grafana/loki | 7.6.0 | `loki-values.yaml` |
| `tempo` | grafana/tempo | 1.24.4 | `tempo-values.yaml` |
| `monitoring` | prometheus-community/kube-prometheus-stack | 93.3.1 | `prometheus-values.yaml` plus the Grafana Ingress |
| `promtail` | grafana/promtail | 6.17.1 | `promtail-values.yaml` |

`storage-class.yaml` is the `gp3` class. Terraform reads that file and creates
it. The EBS CSI driver is an EKS add-on with its own IRSA role.

The load balancer controller chart is 1.17.1, which ships controller v2.17.1.
The IAM policy next to it is the v2.17.1 policy. The Ingress annotations in
the application chart are the ones that controller understands.

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

The worker group is `t3.large` with two nodes. If pods stay Pending, raise
`node_desired_size` and run `terraform apply -var install_platform=true`.
