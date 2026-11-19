variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
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

variable "external_secrets_role_arn" {
  type = string
}

variable "external_dns_role_arn" {
  type = string
}

variable "load_balancer_role_arn" {
  type = string
}
