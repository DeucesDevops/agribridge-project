variable "expected_account_id" {
  description = "Account approved for the cluster rebuild."
  type        = string
  default     = "237258628535"
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID."
  }
}
