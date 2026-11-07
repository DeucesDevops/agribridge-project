variable "environments" { type = set(string) }
variable "secret_names" {
  description = "Optional environment-to-name overrides for runtime secrets."
  type        = map(string)
  default     = {}
}
variable "account_id" { type = string }
variable "oidc" { type = string }
variable "workload_token_audience" { type = string }
