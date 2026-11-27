variable "kops_state_bucket" {
  description = "S3 bucket kOps uses as KOPS_STATE_STORE, without the s3:// prefix."
  type        = string
}

variable "discovery_bucket" {
  description = "Public S3 bucket for the kOps service-account issuer. Must match discoveryStore in kops/cluster.yaml and must not contain dots."
  type        = string
}

variable "backup_bucket" {
  description = "S3 bucket for PostgreSQL dumps. Empty uses agribridge-backups-ACCOUNT_ID."
  type        = string
  default     = ""
}

variable "environments" {
  description = "Secrets Manager names keyed by environment. The only key is production."
  type        = map(string)
}

variable "secret_keys" {
  description = "JSON keys stored in each application secret."
  type        = list(string)
}
