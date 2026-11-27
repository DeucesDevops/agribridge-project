module "dns" {
  source = "../../modules/dns"

  zone_name = var.zone_name
}

module "storage" {
  source = "../../modules/storage"

  kops_state_bucket = var.kops_state_bucket
  discovery_bucket  = var.discovery_bucket
  backup_bucket     = var.backup_bucket
  environments      = local.environments
  secret_keys       = local.secret_keys
}

module "network" {
  source = "../../modules/network"
}

module "cluster" {
  source = "../../modules/cluster"

  providers = {
    aws.files = aws.files
  }

  vpc_id                = module.network.vpc_id
  vpc_cidr_block        = module.network.vpc_cidr_block
  vpc_ipv6_cidr_block   = module.network.vpc_ipv6_cidr_block
  public_subnet_ids     = module.network.public_subnet_ids
  public_route_table_id = module.network.public_route_table_id

  # Buckets and the zone have to exist before kOps uploads node configuration.
  # The network module is an input above, so the VPC exists first.
  depends_on = [
    module.storage,
    module.dns,
  ]
}

module "identity" {
  source = "../../modules/identity"

  region                          = var.region
  github_repository               = var.github_repository
  github_reviewer                 = var.github_reviewer
  manage_github                   = var.manage_github
  create_github_oidc_provider     = var.create_github_oidc_provider
  github_oidc_provider_arn        = var.github_oidc_provider_arn
  github_immutable_subject_prefix = var.github_immutable_subject_prefix
  kops_state_bucket               = module.storage.kops_state_bucket
  kops_state_bucket_arn           = module.storage.kops_state_bucket_arn
  backup_bucket                   = module.storage.backup_bucket
  backup_bucket_arn               = module.storage.backup_bucket_arn
  kms_key_arn                     = module.storage.kms_key_arn
  app_secret_arns                 = module.storage.app_secret_arns
  zone_arn                        = module.dns.zone_arn
  oidc_provider_arn               = module.cluster.iam_openid_connect_provider_arn
  oidc_issuer_host                = module.cluster.iam_openid_connect_provider_issuer
  cluster_name                    = var.cluster_name
  zone_name                       = var.zone_name
  certificate_arn                 = module.dns.certificate_arn
  production_hostname             = local.production_hostname
  grafana_hostname                = local.grafana_hostname
  argocd_hostname                 = local.argocd_hostname
}

module "platform" {
  source   = "../../modules/platform"
  for_each = var.install_platform ? toset(["production"]) : toset([])

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  region                    = var.region
  zone_name                 = var.zone_name
  certificate_arn           = module.dns.certificate_arn
  grafana_hostname          = local.grafana_hostname
  grafana_admin_password    = module.storage.grafana_admin_password
  argocd_hostname           = local.argocd_hostname
  production_hostname       = local.production_hostname
  github_repository         = var.github_repository
  backup_bucket             = module.storage.backup_bucket
  backup_role_arn           = module.identity.backup_role_arn
  external_secrets_role_arn = module.identity.external_secrets_role_arn
  external_dns_role_arn     = module.identity.external_dns_role_arn

  depends_on = [module.cluster]
}
