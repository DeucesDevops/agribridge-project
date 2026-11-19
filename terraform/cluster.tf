module "kops" {
  source = "./kops"

  providers = {
    aws.files = aws.files
  }

  # The state and discovery buckets have to exist before kOps uploads the
  # node configuration. The zone has to exist before the API record is useful.
  depends_on = [
    aws_s3_bucket_public_access_block.kops_state,
    aws_s3_bucket_versioning.kops_state,
    aws_s3_bucket_server_side_encryption_configuration.kops_state,
    aws_s3_bucket_policy.discovery,
    aws_route53_zone.app,
  ]
}
