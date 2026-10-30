terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
  }
}
provider "aws" { region = var.region }
variable "region" { default = "us-east-1" }
variable "zone_name" { default = "agribridge.deuces.dev" }
variable "cluster_name" { default = "k8s.agribridge.deuces.dev" }
variable "repository" { default = "DeucesDevops/agribridge-project" }
variable "discovery_bucket" { type = string }
data "aws_caller_identity" "current" {}
data "aws_route53_zone" "app" { name = var.zone_name }
locals {
  environments = toset(["staging", "production"])
  oidc         = "${var.discovery_bucket}.s3.${var.region}.amazonaws.com"
}
resource "random_password" "secret" {
  for_each = toset(["staging-PGPASSWORD", "staging-JWT_SECRET", "staging-SEED_PASSWORD", "production-PGPASSWORD", "production-JWT_SECRET", "production-SEED_PASSWORD"])
  length   = 40
  special  = false
}
resource "aws_secretsmanager_secret" "app" {
  for_each = local.environments
  name     = "agribridge-${each.key}/runtime"
}
resource "aws_secretsmanager_secret_version" "app" {
  for_each      = local.environments
  secret_id     = aws_secretsmanager_secret.app[each.key].id
  secret_string = jsonencode({ for k in ["PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"] : k => random_password.secret["${each.key}-${k}"].result })
}
resource "aws_ecr_repository" "app" {
  for_each             = toset(["api", "web"])
  name                 = "agribridge-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
resource "aws_acm_certificate" "app" {
  domain_name               = var.zone_name
  subject_alternative_names = ["*.${var.zone_name}"]
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
}
resource "aws_route53_record" "validation" {
  for_each = { for d in aws_acm_certificate.app.domain_validation_options : d.domain_name => d if d.domain_name == var.zone_name }
  zone_id  = data.aws_route53_zone.app.zone_id
  name     = each.value.resource_record_name
  type     = each.value.resource_record_type
  records  = [each.value.resource_record_value]
  ttl      = 60
}
resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_role" "pipeline" {
  name               = "agribridge-pipeline"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = aws_iam_openid_connect_provider.github.arn }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com", "token.actions.githubusercontent.com:sub" = [for e in local.environments : "repo:${var.repository}:environment:${e}"] } } }] })
}
resource "aws_iam_role_policy" "pipeline" {
  role = aws_iam_role.pipeline.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"], Resource = [for r in aws_ecr_repository.app : r.arn] },
    { Effect = "Allow", Action = ["ssm:GetParameter"], Resource = [for p in aws_ssm_parameter.deployment : p.arn] },
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:agribridge-*/deploy-*" }
  ] })
}
resource "aws_iam_role" "secrets" {
  name               = "agribridge-external-secrets"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc}" }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${local.oidc}:sub" = "system:serviceaccount:external-secrets:external-secrets", "${local.oidc}:aud" = "sts.amazonaws.com" } } }] })
}
resource "aws_iam_role_policy" "secrets" {
  role   = aws_iam_role.secrets.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = [for s in aws_secretsmanager_secret.app : s.arn] }] })
}
resource "aws_s3_bucket" "backups" {
  bucket = "agribridge-backups-${data.aws_caller_identity.current.account_id}"
}
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "retention"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}
resource "aws_iam_role" "backup" {
  for_each           = local.environments
  name               = "agribridge-${each.key}-backup"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc}" }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${local.oidc}:sub" = "system:serviceaccount:agribridge-${each.key}:agribridge-backup", "${local.oidc}:aud" = "sts.amazonaws.com" } } }] })
}
resource "aws_iam_role_policy" "backup" {
  for_each = local.environments
  role     = aws_iam_role.backup[each.key].id
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.backups.arn}/${each.key}/*" }] })
}
resource "aws_ssm_parameter" "deployment" {
  for_each = local.environments
  name     = "/agribridge/${each.key}/deployment"
  type     = "String"
  value = jsonencode({
    region         = var.region, namespace = "agribridge-${each.key}", hostname = "${each.key}.${var.zone_name}",
    api_repository = aws_ecr_repository.app["api"].repository_url, web_repository = aws_ecr_repository.app["web"].repository_url,
    secret_arn     = aws_secretsmanager_secret.app[each.key].arn,
    backup_bucket  = aws_s3_bucket.backups.id, backup_role = aws_iam_role.backup[each.key].arn,
    deploy_secret  = "agribridge-${each.key}/deploy"
  })
}
output "pipeline_role" { value = aws_iam_role.pipeline.arn }
output "platform" {
  value = { region = var.region, certificate_arn = aws_acm_certificate_validation.app.certificate_arn, zone_id = data.aws_route53_zone.app.zone_id, zone_name = var.zone_name, secrets_role = aws_iam_role.secrets.arn, logs_role = aws_iam_role.logs.arn }
}
