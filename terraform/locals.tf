locals {
  github_owner = split("/", var.github_repository)[0]
  github_name  = split("/", var.github_repository)[1]

  github_oidc_provider_arn = (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : var.github_oidc_provider_arn
  )

  # Secret name consumed by the Helm chart. Keep helm/agribridge/values-production.yaml in step with this.
  environments = {
    production = "agribridge/production"
  }

  secret_keys = ["PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"]

  backup_bucket_name = (
    var.backup_bucket != ""
    ? var.backup_bucket
    : "agribridge-backups-${data.aws_caller_identity.current.account_id}"
  )

  production_hostname = "production.${var.zone_name}"
  grafana_hostname    = "grafana.${var.zone_name}"

  # kOps pod-identity webhook puts audience amazonaws.com on the token.
  # The load balancer controller and the EBS driver roles are in the kOps output.
  irsa_trust = {
    external_secrets = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
    external_dns = {
      namespace       = "external-dns"
      service_account = "external-dns"
    }
    backup_production = {
      namespace       = "agribridge-production"
      service_account = "agribridge-backup"
    }
  }
}

data "aws_caller_identity" "current" {}
