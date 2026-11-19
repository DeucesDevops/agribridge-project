data "github_user" "reviewer" {
  count    = var.manage_github ? 1 : 0
  username = var.github_reviewer
}

locals {
  github_variables = var.manage_github ? {
    AWS_ROLE_ARN           = aws_iam_role.github.arn
    AWS_REGION             = var.region
    ACM_CERTIFICATE_ARN    = aws_acm_certificate_validation.app.certificate_arn
    KOPS_CLUSTER_NAME      = var.cluster_name
    KOPS_STATE_STORE       = "s3://${aws_s3_bucket.kops_state.bucket}"
    ZONE_NAME              = var.zone_name
    PRODUCTION_URL         = "https://${local.production_hostname}"
    GRAFANA_URL            = "https://${local.grafana_hostname}"
    BACKUP_BUCKET          = aws_s3_bucket.backups.bucket
    BACKUP_ROLE_PRODUCTION = aws_iam_role.backup_production.arn
  } : {}
}

resource "github_actions_variable" "this" {
  for_each = local.github_variables

  repository    = local.github_name
  variable_name = each.key
  value         = each.value
}

resource "github_repository_environment" "production" {
  count = var.manage_github ? 1 : 0

  repository          = local.github_name
  environment         = "production"
  prevent_self_review = false

  reviewers {
    users = [data.github_user.reviewer[0].id]
  }
}
