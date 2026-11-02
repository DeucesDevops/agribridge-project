variable "platform" { type = map(string) }
variable "kubeconfig_path" { type = string }
variable "expected_account_id" {
  type    = string
  default = "237258628535"
}
variable "enable_legacy_pipeline" {
  description = "Create the former direct-Helm pipeline credentials only when explicitly requested."
  type        = bool
  default     = false
}
variable "enable_argocd" {
  description = "Install the reviewed Argo CD controller for the GitOps stage."
  type        = bool
  default     = false
}
