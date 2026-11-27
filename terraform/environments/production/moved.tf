# State addresses from the previous single root. The AWS environment is torn
# down; these blocks keep an old state file from recreating buckets, secrets,
# roles, and the cluster on the next apply.

moved {
  from = module.kops
  to   = module.cluster
}

# Network resources leave the kOps module after the module rename above.
moved {
  from = module.cluster.aws_vpc.k8s-agribridge-deuces-dev
  to   = module.network.aws_vpc.k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_subnet.us-east-1a-k8s-agribridge-deuces-dev
  to   = module.network.aws_subnet.us-east-1a-k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_subnet.us-east-1b-k8s-agribridge-deuces-dev
  to   = module.network.aws_subnet.us-east-1b-k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_internet_gateway.k8s-agribridge-deuces-dev
  to   = module.network.aws_internet_gateway.k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_route_table.k8s-agribridge-deuces-dev
  to   = module.network.aws_route_table.k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_route.route-0-0-0-0--0
  to   = module.network.aws_route.route-0-0-0-0--0
}

moved {
  from = module.cluster.aws_route.route-__--0
  to   = module.network.aws_route.route-__--0
}

moved {
  from = module.cluster.aws_route_table_association.us-east-1a-k8s-agribridge-deuces-dev
  to   = module.network.aws_route_table_association.us-east-1a-k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_route_table_association.us-east-1b-k8s-agribridge-deuces-dev
  to   = module.network.aws_route_table_association.us-east-1b-k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_vpc_dhcp_options.k8s-agribridge-deuces-dev
  to   = module.network.aws_vpc_dhcp_options.k8s-agribridge-deuces-dev
}

moved {
  from = module.cluster.aws_vpc_dhcp_options_association.k8s-agribridge-deuces-dev
  to   = module.network.aws_vpc_dhcp_options_association.k8s-agribridge-deuces-dev
}

moved {
  from = module.platform[0]
  to   = module.platform["production"]
}

moved {
  from = aws_route53_zone.app
  to   = module.dns.aws_route53_zone.app
}

moved {
  from = aws_acm_certificate.app
  to   = module.dns.aws_acm_certificate.app
}

moved {
  from = aws_route53_record.validation
  to   = module.dns.aws_route53_record.validation
}

moved {
  from = aws_acm_certificate_validation.app
  to   = module.dns.aws_acm_certificate_validation.app
}

moved {
  from = aws_s3_bucket.kops_state
  to   = module.storage.aws_s3_bucket.kops_state
}

moved {
  from = aws_s3_bucket_versioning.kops_state
  to   = module.storage.aws_s3_bucket_versioning.kops_state
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.kops_state
  to   = module.storage.aws_s3_bucket_server_side_encryption_configuration.kops_state
}

moved {
  from = aws_s3_bucket_public_access_block.kops_state
  to   = module.storage.aws_s3_bucket_public_access_block.kops_state
}

moved {
  from = aws_s3_bucket.discovery
  to   = module.storage.aws_s3_bucket.discovery
}

moved {
  from = aws_s3_bucket_public_access_block.discovery
  to   = module.storage.aws_s3_bucket_public_access_block.discovery
}

moved {
  from = aws_s3_bucket_policy.discovery
  to   = module.storage.aws_s3_bucket_policy.discovery
}

moved {
  from = aws_s3_bucket.backups
  to   = module.storage.aws_s3_bucket.backups
}

moved {
  from = aws_s3_bucket_versioning.backups
  to   = module.storage.aws_s3_bucket_versioning.backups
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.backups
  to   = module.storage.aws_s3_bucket_server_side_encryption_configuration.backups
}

moved {
  from = aws_s3_bucket_public_access_block.backups
  to   = module.storage.aws_s3_bucket_public_access_block.backups
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.backups
  to   = module.storage.aws_s3_bucket_lifecycle_configuration.backups
}

moved {
  from = aws_s3_bucket_policy.backups
  to   = module.storage.aws_s3_bucket_policy.backups
}

moved {
  from = aws_kms_key.secrets
  to   = module.storage.aws_kms_key.secrets
}

moved {
  from = aws_kms_alias.secrets
  to   = module.storage.aws_kms_alias.secrets
}

moved {
  from = random_password.app
  to   = module.storage.random_password.app
}

moved {
  from = random_password.grafana
  to   = module.storage.random_password.grafana
}

moved {
  from = aws_secretsmanager_secret.app
  to   = module.storage.aws_secretsmanager_secret.app
}

moved {
  from = aws_secretsmanager_secret_version.app
  to   = module.storage.aws_secretsmanager_secret_version.app
}

moved {
  from = aws_secretsmanager_secret.grafana
  to   = module.storage.aws_secretsmanager_secret.grafana
}

moved {
  from = aws_secretsmanager_secret_version.grafana
  to   = module.storage.aws_secretsmanager_secret_version.grafana
}

moved {
  from = aws_iam_openid_connect_provider.github[0]
  to   = module.identity.aws_iam_openid_connect_provider.github["github"]
}

moved {
  from = aws_iam_role.github
  to   = module.identity.aws_iam_role.github
}

moved {
  from = aws_iam_role_policy.github
  to   = module.identity.aws_iam_role_policy.github
}

moved {
  from = aws_iam_role.external_secrets[0]
  to   = aws_iam_role.external_secrets
}

moved {
  from = aws_iam_role.external_secrets
  to   = module.identity.aws_iam_role.irsa["external_secrets"]
}

moved {
  from = aws_iam_role_policy.external_secrets[0]
  to   = aws_iam_role_policy.external_secrets
}

moved {
  from = aws_iam_role_policy.external_secrets
  to   = module.identity.aws_iam_role_policy.irsa["external_secrets"]
}

moved {
  from = aws_iam_role.external_dns[0]
  to   = aws_iam_role.external_dns
}

moved {
  from = aws_iam_role.external_dns
  to   = module.identity.aws_iam_role.irsa["external_dns"]
}

moved {
  from = aws_iam_role_policy.external_dns[0]
  to   = aws_iam_role_policy.external_dns
}

moved {
  from = aws_iam_role_policy.external_dns
  to   = module.identity.aws_iam_role_policy.irsa["external_dns"]
}

moved {
  from = aws_iam_role.backup_production
  to   = module.identity.aws_iam_role.irsa["backup_production"]
}

moved {
  from = aws_iam_role_policy.backup_production
  to   = module.identity.aws_iam_role_policy.irsa["backup_production"]
}

moved {
  from = github_actions_variable.this
  to   = module.identity.github_actions_variable.this
}

moved {
  from = github_repository_environment.production[0]
  to   = module.identity.github_repository_environment.production["production"]
}
