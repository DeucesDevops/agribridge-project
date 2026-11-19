variable "region" {
  description = "AWS region for the cluster, the certificate and the backup bucket."
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Public DNS zone Terraform creates, for example agribridge.deuces.dev."
  type        = string
  default     = "agribridge.deuces.dev"
}

variable "cluster_name" {
  description = "kOps cluster name. Must match metadata.name in kops/cluster.yaml."
  type        = string
  default     = "k8s.agribridge.deuces.dev"
}

variable "kops_state_bucket" {
  description = "S3 bucket kOps uses as KOPS_STATE_STORE, without the s3:// prefix."
  type        = string
  default     = "kops-state-607"
}

variable "discovery_bucket" {
  description = "Public S3 bucket for the kOps service-account issuer. Must match discoveryStore in kops/cluster.yaml and must not contain dots."
  type        = string
  default     = "agribridge-oidc-237258628535"
}

variable "kubeconfig_path" {
  description = "Kubeconfig written by kops export kubeconfig --admin. Required for the platform apply."
  type        = string
  default     = "~/.kube/config"
}

variable "backup_bucket" {
  description = "S3 bucket for PostgreSQL dumps. Empty uses agribridge-backups-ACCOUNT_ID."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as OWNER/NAME."
  type        = string
  default     = "DeucesDevops/agribridge-project"
}

variable "github_reviewer" {
  description = "GitHub login Terraform adds as the required reviewer on the production environment."
  type        = string
  default     = "DeucesDevops"
}

variable "manage_github" {
  description = "Publish Actions variables and the qa and production environments. Requires GITHUB_TOKEN."
  type        = bool
  default     = true
}

variable "install_platform" {
  description = "Install the cluster add-ons with the Helm provider. Leave false on the first apply. Set true once the API answers."
  type        = bool
  default     = false
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false when this account already has one."
  type        = bool
  default     = true
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
  default     = "repo:DeucesDevops@132962088/agribridge-project@1409286862"
}
