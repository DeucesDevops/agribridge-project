variable "region" { default = "us-east-1" }

variable "zone_name" { default = "agribridge.deuces.dev" }

variable "cluster_name" { default = "k8s.agribridge.deuces.dev" }

variable "repository_subject_prefix" { default = "repo:DeucesDevops@132962088/agribridge-project@1409286862" }

variable "discovery_bucket" { type = string }
# kOps configures the pod identity webhook and AWS OIDC provider with this audience.

variable "workload_token_audience" { default = "amazonaws.com" }
variable "environments" {
  type    = set(string)
  default = ["staging", "production"]
}

variable "dockerhub_username" {
  type    = string
  default = "macroni607"
}
