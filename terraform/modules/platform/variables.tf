variable "region" {
  description = "AWS region ExternalDNS uses as AWS_DEFAULT_REGION."
  type        = string
}

variable "zone_name" {
  description = "Domain filter for ExternalDNS."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN attached to the Grafana and Argo CD ingresses."
  type        = string
}

variable "grafana_hostname" {
  description = "Grafana hostname, without the scheme."
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Also stored in Secrets Manager by the storage module."
  type        = string
  sensitive   = true
}

variable "argocd_hostname" {
  description = "Argo CD hostname, without the scheme."
  type        = string
}

variable "production_hostname" {
  description = "Application hostname passed to the Argo CD Application."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository Argo CD syncs, as OWNER/NAME."
  type        = string
}

variable "backup_bucket" {
  description = "S3 bucket the production backup CronJob writes to."
  type        = string
}

variable "backup_role_arn" {
  description = "IRSA role ARN for the production backup service account."
  type        = string
}

variable "external_secrets_role_arn" {
  description = "IRSA role ARN for the External Secrets service account."
  type        = string
}

variable "external_dns_role_arn" {
  description = "IRSA role ARN for the ExternalDNS service account."
  type        = string
}
