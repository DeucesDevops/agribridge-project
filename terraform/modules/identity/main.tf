locals {
  github_name = split("/", var.github_repository)[1]

  # concat keeps the index valid when create_github_oidc_provider is false
  # and the for_each set is empty. The created provider wins when it exists.
  github_oidc_provider_arn = concat(
    aws_iam_openid_connect_provider.github[*].arn,
    [var.github_oidc_provider_arn],
  )[0]

  # Keys are static so for_each does not wait on ARNs computed during apply.
  irsa_roles = {
    external_secrets = {
      name            = "agribridge-external-secrets"
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
    external_dns = {
      name            = "agribridge-external-dns"
      namespace       = "external-dns"
      service_account = "external-dns"
    }
    backup_production = {
      name            = "agribridge-backup-production"
      namespace       = "agribridge-production"
      service_account = "agribridge-backup"
    }
  }

  github_variable_names = toset([
    "AWS_ROLE_ARN",
    "AWS_REGION",
    "ACM_CERTIFICATE_ARN",
    "KOPS_CLUSTER_NAME",
    "KOPS_STATE_STORE",
    "ZONE_NAME",
    "PRODUCTION_URL",
    "GRAFANA_URL",
    "ARGOCD_URL",
    "BACKUP_BUCKET",
    "BACKUP_ROLE_PRODUCTION",
  ])

  github_variable_values = {
    AWS_ROLE_ARN           = aws_iam_role.github.arn
    AWS_REGION             = var.region
    ACM_CERTIFICATE_ARN    = var.certificate_arn
    KOPS_CLUSTER_NAME      = var.cluster_name
    KOPS_STATE_STORE       = "s3://${var.kops_state_bucket}"
    ZONE_NAME              = var.zone_name
    PRODUCTION_URL         = "https://${var.production_hostname}"
    GRAFANA_URL            = "https://${var.grafana_hostname}"
    ARGOCD_URL             = "https://${var.argocd_hostname}"
    BACKUP_BUCKET          = var.backup_bucket
    BACKUP_ROLE_PRODUCTION = aws_iam_role.irsa["backup_production"].arn
  }
}
