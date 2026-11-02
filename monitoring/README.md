# Monitoring configuration

Terraform installs these values through `terraform/platform`:

- `prometheus-values.yaml`: Prometheus metrics and Grafana, with encrypted gp3 persistence.
- `fluent-bit-values.yaml.tftpl`: container logs sent to CloudWatch. Terraform supplies the region and workload role; no credentials belong here.

Application scrape targets and alert rules are in `helm/agribridge/templates/monitoring.yaml` so they follow each environment's release. Dashboard access and useful queries are documented in `docs/OPERATIONS.md`.
