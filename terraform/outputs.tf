output "region" {
  value = var.region
}

output "cluster_name" {
  value = var.cluster_name
}

output "kops_state_store" {
  value = "s3://${aws_s3_bucket.kops_state.bucket}"
}

output "discovery_bucket" {
  value = aws_s3_bucket.discovery.bucket
}

output "zone_name" {
  value = var.zone_name
}

output "qa_hostname" {
  value = "qa.${var.zone_name}"
}

output "production_hostname" {
  value = "production.${var.zone_name}"
}

output "certificate_arn" {
  description = "Copy this into the GitHub variable ACM_CERTIFICATE_ARN."
  value       = aws_acm_certificate_validation.app.certificate_arn
}

output "github_actions_role_arn" {
  description = "Copy this into the GitHub variable AWS_ROLE_ARN."
  value       = aws_iam_role.github.arn
}

output "api_repository_url" {
  value = aws_ecr_repository.app["agribridge-api"].repository_url
}

output "web_repository_url" {
  value = aws_ecr_repository.app["agribridge-web"].repository_url
}

output "qa_secret_name" {
  value = aws_secretsmanager_secret.app["qa"].name
}

output "production_secret_name" {
  value = aws_secretsmanager_secret.app["production"].name
}

output "external_secrets_role_arn" {
  value = one(aws_iam_role.external_secrets[*].arn)
}

output "external_dns_role_arn" {
  value = one(aws_iam_role.external_dns[*].arn)
}
