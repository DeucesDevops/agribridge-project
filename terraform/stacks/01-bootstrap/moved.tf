moved {
  from = aws_s3_bucket.state
  to   = module.bootstrap.aws_s3_bucket.state
}

moved {
  from = aws_s3_bucket_versioning.state
  to   = module.bootstrap.aws_s3_bucket_versioning.state
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.state
  to   = module.bootstrap.aws_s3_bucket_server_side_encryption_configuration.state
}

moved {
  from = aws_s3_bucket_public_access_block.state
  to   = module.bootstrap.aws_s3_bucket_public_access_block.state
}

moved {
  from = aws_s3_bucket_policy.state
  to   = module.bootstrap.aws_s3_bucket_policy.state
}

moved {
  from = aws_s3_bucket.discovery
  to   = module.bootstrap.aws_s3_bucket.discovery
}

moved {
  from = aws_s3_bucket_public_access_block.discovery
  to   = module.bootstrap.aws_s3_bucket_public_access_block.discovery
}

moved {
  from = aws_s3_bucket_policy.discovery
  to   = module.bootstrap.aws_s3_bucket_policy.discovery
}

moved {
  from = aws_s3_bucket.kops
  to   = module.bootstrap.aws_s3_bucket.kops
}

moved {
  from = aws_s3_bucket_versioning.kops
  to   = module.bootstrap.aws_s3_bucket_versioning.kops
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.kops
  to   = module.bootstrap.aws_s3_bucket_server_side_encryption_configuration.kops
}

moved {
  from = aws_s3_bucket_public_access_block.kops
  to   = module.bootstrap.aws_s3_bucket_public_access_block.kops
}

moved {
  from = aws_route53_zone.app
  to   = module.bootstrap.aws_route53_zone.app
}
