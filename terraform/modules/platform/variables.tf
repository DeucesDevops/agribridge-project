variable "region" {
  type = string
}

variable "zone_name" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "grafana_hostname" {
  type = string
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "argocd_hostname" {
  type = string
}

variable "production_hostname" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "backup_bucket" {
  type = string
}

variable "backup_role_arn" {
  type = string
}

variable "external_secrets_role_arn" {
  type = string
}

variable "external_dns_role_arn" {
  type = string
}
