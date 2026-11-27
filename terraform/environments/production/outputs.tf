output "region" {
  description = "AWS region."
  value       = var.region
}

output "cluster_name" {
  description = "Terraform writes this to the GitHub variable KOPS_CLUSTER_NAME."
  value       = var.cluster_name
}

output "kops_state_store" {
  description = "Terraform writes this to the GitHub variable KOPS_STATE_STORE."
  value       = "s3://${module.storage.kops_state_bucket}"
}

output "kops_oidc_provider_arn" {
  description = "IAM OIDC provider rendered by kOps for pod identity."
  value       = module.cluster.iam_openid_connect_provider_arn
}

output "zone_name" {
  description = "Terraform writes this to the GitHub variable ZONE_NAME."
  value       = var.zone_name
}

output "zone_id" {
  description = "Public hosted zone id."
  value       = module.dns.zone_id
}

output "name_servers" {
  description = "Name servers to delegate at the registrar for the parent domain."
  value       = module.dns.name_servers
}

output "production_hostname" {
  description = "Application hostname, without the scheme."
  value       = local.production_hostname
}

output "grafana_hostname" {
  description = "Grafana hostname, without the scheme."
  value       = local.grafana_hostname
}

output "argocd_hostname" {
  description = "Argo CD hostname, without the scheme."
  value       = local.argocd_hostname
}

output "argocd_admin_password_command" {
  description = "Reads the generated Argo CD admin password. The username is admin. This prints the password, so run it on your machine and do not paste the output into git."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}

output "certificate_arn" {
  description = "Terraform writes this to the GitHub variable ACM_CERTIFICATE_ARN."
  value       = module.dns.certificate_arn
}

output "github_actions_role_arn" {
  description = "Terraform writes this to the GitHub variable AWS_ROLE_ARN."
  value       = module.identity.github_actions_role_arn
}

output "production_secret_name" {
  description = "Secrets Manager name for the production application secret."
  value       = module.storage.production_secret_name
}

output "grafana_secret_name" {
  description = "Grafana admin password. Read admin_password with aws secretsmanager get-secret-value."
  value       = module.storage.grafana_secret_name
}

output "backup_bucket" {
  description = "Terraform writes this to the GitHub variable BACKUP_BUCKET."
  value       = module.storage.backup_bucket
}

output "backup_role_production_arn" {
  description = "Terraform writes this to the GitHub variable BACKUP_ROLE_PRODUCTION."
  value       = module.identity.backup_role_arn
}

output "external_secrets_role_arn" {
  description = "IRSA role for External Secrets."
  value       = module.identity.external_secrets_role_arn
}

output "external_dns_role_arn" {
  description = "IRSA role for ExternalDNS."
  value       = module.identity.external_dns_role_arn
}

output "vpc_id" {
  description = "VPC from the network module. Subnets are public and there is no NAT gateway."
  value       = module.network.vpc_id
}

output "node_subnet_ids" {
  description = "Public worker subnet ids from the network module."
  value       = module.network.node_subnet_ids
}

output "kubeconfig_command" {
  description = "Command that writes the admin kubeconfig."
  value       = "kops export kubeconfig --admin --name ${var.cluster_name}"
}
