output "github_actions_role_arn" {
  description = "Role ARN published as the GitHub variable AWS_ROLE_ARN."
  value       = aws_iam_role.github.arn
}

output "external_secrets_role_arn" {
  description = "IRSA role for External Secrets."
  value       = aws_iam_role.irsa["external_secrets"].arn
}

output "external_dns_role_arn" {
  description = "IRSA role for ExternalDNS."
  value       = aws_iam_role.irsa["external_dns"].arn
}

output "backup_role_arn" {
  description = "IRSA role for the production backup CronJob."
  value       = aws_iam_role.irsa["backup_production"].arn
}
