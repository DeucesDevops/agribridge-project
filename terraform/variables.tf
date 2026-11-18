variable "region" {
  description = "AWS region. Must match the kOps cluster."
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Existing public Route 53 zone. kOps dnsZone must be the same name."
  type        = string
  default     = "agribridge.deuces.dev"
}

variable "cluster_name" {
  description = "kOps cluster name (metadata.name in kops/cluster.yaml)."
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

variable "oidc_issuer_url" {
  description = "Issuer URL kOps registered in IAM. Leave empty to use https://DISCOVERY_BUCKET.s3.REGION.amazonaws.com."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as OWNER/NAME."
  type        = string
  default     = "DeucesDevops/agribridge-project"
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

variable "attach_irsa" {
  description = "Create External Secrets and ExternalDNS roles. Set true only after kOps has created the cluster OIDC provider."
  type        = bool
  default     = false
}

variable "github_immutable_subject_prefix" {
  description = "OIDC sub prefix when the repo uses GitHub immutable subjects (repo:OWNER@OWNER_ID/NAME@REPO_ID). See GET /repos/OWNER/NAME/actions/oidc/customization/sub."
  type        = string
  default     = "repo:DeucesDevops@132962088/agribridge-project@1409286862"
}
