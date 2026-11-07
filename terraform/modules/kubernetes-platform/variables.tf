variable "platform" { type = map(string) }
variable "monitoring_values" { type = string }
variable "logging_values" { type = string }
variable "ingress_values" { type = string }
variable "enable_legacy_pipeline" {
  description = "Opt in to legacy deployment service accounts, tokens and deploy secrets."
  type        = bool
  default     = false
}
variable "enable_argocd" {
  type    = bool
  default = false
}
variable "argocd_values" {
  type    = string
  default = ""
}
variable "argocd_bootstrap_chart" {
  type    = string
  default = ""
}
variable "argocd_bootstrap_values" {
  type    = string
  default = ""
}
