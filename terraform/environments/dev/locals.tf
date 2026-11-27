locals {
  github_owner = split("/", var.github_repository)[0]

  # Secret name consumed by the Helm chart. Keep helm/agribridge/values-production.yaml in step with this.
  environments = {
    production = "agribridge/production"
  }

  secret_keys = ["PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"]

  production_hostname = "production.${var.zone_name}"
  grafana_hostname    = "grafana.${var.zone_name}"
  argocd_hostname     = "argocd.${var.zone_name}"
}
