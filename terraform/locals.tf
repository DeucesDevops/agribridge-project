locals {
  github_owner = split("/", var.github_repository)[0]
  github_name  = split("/", var.github_repository)[1]

  github_oidc_provider_arn = (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : var.github_oidc_provider_arn
  )

  # Secret names consumed by the Helm chart. Keep helm/agribridge/values-*.yaml in step with these.
  environments = {
    qa         = "agribridge/qa"
    production = "agribridge/production"
  }

  secret_keys = ["PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"]

  backup_bucket_name = (
    var.backup_bucket != ""
    ? var.backup_bucket
    : "agribridge-backups-${data.aws_caller_identity.current.account_id}"
  )

  qa_hostname         = "qa.${var.zone_name}"
  production_hostname = "production.${var.zone_name}"
  grafana_hostname    = "grafana.${var.zone_name}"

  # One service account per IRSA role. The audience is sts.amazonaws.com,
  # which is what EKS puts on a projected service-account token.
  irsa_trust = {
    external_secrets = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
    external_dns = {
      namespace       = "external-dns"
      service_account = "external-dns"
    }
    load_balancer = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
    ebs_csi = {
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
    backup_production = {
      namespace       = "agribridge-production"
      service_account = "agribridge-backup"
    }
    backup_qa = {
      namespace       = "agribridge-qa"
      service_account = "agribridge-backup"
    }
  }
}

data "aws_caller_identity" "current" {}
