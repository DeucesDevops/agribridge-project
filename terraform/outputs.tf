output "region" {
  value = var.region
}

output "cluster_name" {
  description = "Terraform writes this to the GitHub variable KOPS_CLUSTER_NAME."
  value       = var.cluster_name
}

output "kops_state_store" {
  description = "Terraform writes this to the GitHub variable KOPS_STATE_STORE."
  value       = "s3://${aws_s3_bucket.kops_state.bucket}"
}

output "kops_oidc_provider_arn" {
  value = module.kops.iam_openid_connect_provider_arn
}

output "zone_name" {
  description = "Terraform writes this to the GitHub variable ZONE_NAME."
  value       = var.zone_name
}

output "zone_id" {
  value = aws_route53_zone.app.zone_id
}

output "name_servers" {
  description = "Name servers to delegate at the registrar for the parent domain."
  value       = aws_route53_zone.app.name_servers
}

output "production_hostname" {
  value = local.production_hostname
}

output "grafana_hostname" {
  value = local.grafana_hostname
}

output "certificate_arn" {
  description = "Terraform writes this to the GitHub variable ACM_CERTIFICATE_ARN."
  value       = aws_acm_certificate_validation.app.certificate_arn
}

output "github_actions_role_arn" {
  description = "Terraform writes this to the GitHub variable AWS_ROLE_ARN."
  value       = aws_iam_role.github.arn
}

output "production_secret_name" {
  value = aws_secretsmanager_secret.app["production"].name
}

output "grafana_secret_name" {
  description = "Grafana admin password. Read admin_password with aws secretsmanager get-secret-value."
  value       = aws_secretsmanager_secret.grafana.name
}

output "backup_bucket" {
  description = "Terraform writes this to the GitHub variable BACKUP_BUCKET."
  value       = aws_s3_bucket.backups.bucket
}

output "backup_role_production_arn" {
  description = "Terraform writes this to the GitHub variable BACKUP_ROLE_PRODUCTION."
  value       = aws_iam_role.backup_production.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}

output "kubeconfig_command" {
  value = "kops export kubeconfig --admin --name ${var.cluster_name}"
}
