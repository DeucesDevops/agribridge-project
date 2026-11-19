output "region" {
  value = var.region
}

output "cluster_name" {
  description = "Terraform writes this to the GitHub variable CLUSTER_NAME."
  value       = aws_eks_cluster.this.name
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

output "qa_hostname" {
  value = local.qa_hostname
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

output "qa_secret_name" {
  value = aws_secretsmanager_secret.app["qa"].name
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

output "backup_role_qa_arn" {
  description = "Terraform writes this to the GitHub variable BACKUP_ROLE_QA."
  value       = aws_iam_role.backup_qa.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.region}"
}
