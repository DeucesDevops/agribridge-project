# Monitoring configuration

Terraform installs these values through `terraform/platform`:

- `prometheus-values.yaml`: Prometheus metrics and Grafana, with encrypted gp3 persistence.
- `fluent-bit-values.yaml.tftpl`: container logs sent to CloudWatch. Terraform supplies the region and workload role; no credentials belong here.

Application scrape targets and alert rules are in `helm/agribridge/templates/monitoring.yaml` so they follow each environment's release. Dashboard access and useful queries are documented in [operations](../docs/OPERATIONS.md).

The historical Stage 7 checks are in
[STAGE7-REVIEW.md](../docs/evidence/STAGE7-REVIEW.md). The availability alert is scoped to each
environment and treats missing scrape targets as unavailable. Monitoring values
disable the currently unreachable kOps controller-manager, scheduler and
kube-proxy metric collectors; their component metrics are consequently outside
this scrape configuration. API server, kubelets, CoreDNS, node-exporter and
kube-state-metrics remain enabled.
