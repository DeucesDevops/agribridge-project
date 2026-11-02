variable "region" { default = "us-east-1" }

variable "expected_account_id" {
  description = "AWS account approved for the AgriBridge rebuild."
  type        = string
  default     = "237258628535"
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID."
  }
}

variable "runtime_secret_names" {
  description = "Fresh runtime secret names; v2 avoids names still awaiting deletion after teardown."
  type        = map(string)
  default = {
    staging    = "agribridge-staging/runtime-v2"
    production = "agribridge-production/runtime-v2"
  }
}

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
