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
  description = "EKS cluster name."
  type        = string
  default     = "agribridge"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. 1.36 matches the version this project ran before."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "VPC address range. Public subnets are cut from this."
  type        = string
  default     = "172.20.0.0/16"
}

variable "availability_zones" {
  description = "AZs for the public subnets and the node group. EKS needs two."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 4
    error_message = "Use two, three or four availability zones."
  }
}

variable "node_instance_type" {
  description = "Worker instance type. t3.large has room for the monitoring stack."
  type        = string
  default     = "t3.large"
}

variable "node_desired_size" {
  description = "Worker count. Two spreads the nodes across the AZs."
  type        = number
  default     = 2
}

variable "api_access_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API. GitHub-hosted runners need a public API. Access still requires IAM."
  type        = list(string)
  default     = ["0.0.0.0/0"]
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
