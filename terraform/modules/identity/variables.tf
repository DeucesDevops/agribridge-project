variable "region" {
  description = "AWS region written to the GitHub variable AWS_REGION."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as OWNER/NAME."
  type        = string
}

variable "github_reviewer" {
  description = "GitHub login added as the required reviewer on the production environment."
  type        = string
}

variable "manage_github" {
  description = "Publish Actions variables and the production environment. Requires GITHUB_TOKEN on the provider configured by the root module."
  type        = bool
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false when this account already has one."
  type        = bool
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN, used only when create_github_oidc_provider is false."
  type        = string
  default     = ""

  validation {
    condition     = var.create_github_oidc_provider || length(var.github_oidc_provider_arn) > 0
    error_message = "Set github_oidc_provider_arn when create_github_oidc_provider is false."
  }
}

variable "github_immutable_subject_prefix" {
  description = "OIDC sub prefix when the repo uses GitHub immutable subjects (repo:OWNER@OWNER_ID/NAME@REPO_ID)."
  type        = string
}

variable "kops_state_bucket" {
  description = "kOps state bucket name, without the s3:// prefix."
  type        = string
}

variable "kops_state_bucket_arn" {
  description = "kOps state bucket ARN the GitHub Actions role can read."
  type        = string
}

variable "backup_bucket" {
  description = "Backup bucket name published as the GitHub variable BACKUP_BUCKET."
  type        = string
}

variable "backup_bucket_arn" {
  description = "Backup bucket ARN the production backup role can use."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN External Secrets can decrypt."
  type        = string
}

variable "app_secret_arns" {
  description = "Secrets Manager ARNs External Secrets can read."
  type        = list(string)
}

variable "zone_arn" {
  description = "Route 53 hosted zone ARN ExternalDNS can change."
  type        = string
}

variable "oidc_provider_arn" {
  description = "kOps IAM OIDC provider ARN used by IRSA trust policies."
  type        = string
}

variable "oidc_issuer_host" {
  description = "Host of the kOps OIDC issuer, without the https:// prefix. The pod-identity webhook uses audience amazonaws.com."
  type        = string
}

variable "cluster_name" {
  description = "kOps cluster name published as the GitHub variable KOPS_CLUSTER_NAME."
  type        = string
}

variable "zone_name" {
  description = "Public zone name published as the GitHub variable ZONE_NAME."
  type        = string
}

variable "certificate_arn" {
  description = "Validated ACM certificate ARN published as the GitHub variable ACM_CERTIFICATE_ARN."
  type        = string
}

variable "production_hostname" {
  description = "Production application hostname, without the scheme."
  type        = string
}

variable "grafana_hostname" {
  description = "Grafana hostname, without the scheme."
  type        = string
}

variable "argocd_hostname" {
  description = "Argo CD hostname, without the scheme."
  type        = string
}
