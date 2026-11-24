variable "region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "State bucket name. Empty uses agribridge-tfstate-ACCOUNT_ID."
  type        = string
  default     = ""
}
