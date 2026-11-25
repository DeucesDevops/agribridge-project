output "kops_state_bucket" {
  description = "kOps state bucket name, without the s3:// prefix."
  value       = aws_s3_bucket.kops_state.bucket
}

output "kops_state_bucket_arn" {
  description = "kOps state bucket ARN."
  value       = aws_s3_bucket.kops_state.arn
}

output "discovery_bucket" {
  description = "OIDC discovery bucket name."
  value       = aws_s3_bucket.discovery.bucket
}

output "backup_bucket" {
  description = "PostgreSQL backup bucket name."
  value       = aws_s3_bucket.backups.bucket
}

output "backup_bucket_arn" {
  description = "PostgreSQL backup bucket ARN."
  value       = aws_s3_bucket.backups.arn
}

output "kms_key_arn" {
  description = "KMS key that encrypts the application and Grafana secrets."
  value       = aws_kms_key.secrets.arn
}

output "app_secret_arns" {
  description = "Application secret ARNs External Secrets is allowed to read."
  value       = [for secret in aws_secretsmanager_secret.app : secret.arn]
}

output "production_secret_name" {
  description = "Secrets Manager name for the production application secret."
  value       = aws_secretsmanager_secret.app["production"].name
}

output "grafana_secret_name" {
  description = "Secrets Manager name for the Grafana admin password."
  value       = aws_secretsmanager_secret.grafana.name
}

output "grafana_admin_password" {
  description = "Grafana admin password stored in Secrets Manager. Passed to the platform module."
  value       = random_password.grafana.result
  sensitive   = true
}
