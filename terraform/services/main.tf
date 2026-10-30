data "aws_caller_identity" "current" {}
data "aws_route53_zone" "app" { name = var.zone_name }
locals { oidc = "${var.discovery_bucket}.s3.${var.region}.amazonaws.com" }
module "registry" {
  source             = "../modules/registry"
  dockerhub_username = var.dockerhub_username
}
module "runtime_secrets" {
  source                  = "../modules/runtime-secrets"
  environments            = var.environments
  account_id              = data.aws_caller_identity.current.account_id
  oidc                    = local.oidc
  workload_token_audience = var.workload_token_audience
}
module "tls" {
  source    = "../modules/tls"
  zone_name = var.zone_name
  zone_id   = data.aws_route53_zone.app.zone_id
}
module "backups" {
  source                  = "../modules/backups"
  environments            = var.environments
  account_id              = data.aws_caller_identity.current.account_id
  oidc                    = local.oidc
  workload_token_audience = var.workload_token_audience
}
module "observability" {
  source                  = "../modules/observability"
  account_id              = data.aws_caller_identity.current.account_id
  oidc                    = local.oidc
  workload_token_audience = var.workload_token_audience
  cluster_name            = var.cluster_name
}
module "deployment_config" {
  source        = "../modules/deployment-config"
  environments  = var.environments
  region        = var.region
  zone_name     = var.zone_name
  repositories  = module.registry.repositories
  secret_arns   = module.runtime_secrets.secret_arns
  backup_bucket = module.backups.bucket
  backup_roles  = module.backups.role_arns
}
module "github_delivery" {
  source                    = "../modules/github-delivery"
  region                    = var.region
  account_id                = data.aws_caller_identity.current.account_id
  environments              = var.environments
  repository_subject_prefix = var.repository_subject_prefix
  parameter_arns            = module.deployment_config.parameter_arns
}
