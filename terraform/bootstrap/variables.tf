variable "region" {
  type    = string
  default = "us-east-1"
}
variable "kops_state_bucket" { default = "kops-state-607" }
variable "zone_name" { default = "agribridge.deuces.dev" }

variable "expected_account_id" {
  description = "Account approved for this rebuild; refuse to plan or apply elsewhere."
  type        = string
  default     = "237258628535"
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID."
  }
}
