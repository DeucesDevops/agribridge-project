variable "dockerhub_username" { type = string }
variable "manage_legacy_ecr" {
  description = "Manage the former ECR repositories only when explicitly retaining them."
  type        = bool
  default     = false
}
