moved {
  from = aws_ecr_repository.app
  to   = module.registry.aws_ecr_repository.app
}

moved {
  from = random_password.secret
  to   = module.runtime_secrets.random_password.secret
}

moved {
  from = aws_secretsmanager_secret.app
  to   = module.runtime_secrets.aws_secretsmanager_secret.app
}

moved {
  from = aws_secretsmanager_secret_version.app
  to   = module.runtime_secrets.aws_secretsmanager_secret_version.app
}

moved {
  from = aws_acm_certificate.app
  to   = module.tls.aws_acm_certificate.app
}

moved {
  from = aws_route53_record.validation
  to   = module.tls.aws_route53_record.validation
}

moved {
  from = aws_acm_certificate_validation.app
  to   = module.tls.aws_acm_certificate_validation.app
}

moved {
  from = aws_s3_bucket.backups
  to   = module.backups.aws_s3_bucket.backups
}

moved {
  from = aws_s3_bucket_versioning.backups
  to   = module.backups.aws_s3_bucket_versioning.backups
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.backups
  to   = module.backups.aws_s3_bucket_server_side_encryption_configuration.backups
}

moved {
  from = aws_s3_bucket_public_access_block.backups
  to   = module.backups.aws_s3_bucket_public_access_block.backups
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.backups
  to   = module.backups.aws_s3_bucket_lifecycle_configuration.backups
}

moved {
  from = aws_iam_role.backup
  to   = module.backups.aws_iam_role.backup
}

moved {
  from = aws_iam_role_policy.backup
  to   = module.backups.aws_iam_role_policy.backup
}

moved {
  from = aws_iam_openid_connect_provider.github
  to   = module.github_delivery.aws_iam_openid_connect_provider.github
}

moved {
  from = aws_iam_role.pipeline
  to   = module.github_delivery.aws_iam_role.pipeline
}

moved {
  from = aws_iam_role_policy.pipeline
  to   = module.github_delivery.aws_iam_role_policy.pipeline
}

moved {
  from = aws_ssm_parameter.deployment
  to   = module.deployment_config.aws_ssm_parameter.deployment
}

moved {
  from = aws_iam_role.secrets
  to   = module.runtime_secrets.aws_iam_role.secrets
}

moved {
  from = aws_iam_role_policy.secrets
  to   = module.runtime_secrets.aws_iam_role_policy.secrets
}

moved {
  from = aws_cloudwatch_log_group.app
  to   = module.observability.aws_cloudwatch_log_group.app
}

moved {
  from = aws_iam_role.logs
  to   = module.observability.aws_iam_role.logs
}

moved {
  from = aws_iam_role_policy.logs
  to   = module.observability.aws_iam_role_policy.logs
}

moved {
  from = aws_iam_role_policy_attachment.node_ssm
  to   = module.observability.aws_iam_role_policy_attachment.node_ssm
}
