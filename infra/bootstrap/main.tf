terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" { region = "us-east-1" }
data "aws_caller_identity" "current" {}
resource "aws_s3_bucket" "state" {
  bucket = "agribridge-tfstate-${data.aws_caller_identity.current.account_id}"
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }] })
}
output "bucket" { value = aws_s3_bucket.state.id }
resource "aws_s3_bucket" "discovery" {
  bucket = "agribridge-oidc-${data.aws_caller_identity.current.account_id}"
}
resource "aws_s3_bucket_public_access_block" "discovery" {
  bucket                  = aws_s3_bucket.discovery.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "discovery" {
  depends_on = [aws_s3_bucket_public_access_block.discovery]
  bucket     = aws_s3_bucket.discovery.id
  policy     = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = "s3:GetObject", Resource = "${aws_s3_bucket.discovery.arn}/*" }] })
}
output "discovery_store" { value = "s3://${aws_s3_bucket.discovery.id}" }
variable "kops_state_bucket" { default = "kops-state-607" }
variable "zone_name" { default = "agribridge.deuces.dev" }
resource "aws_s3_bucket" "kops" {
  bucket = var.kops_state_bucket
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_versioning" "kops" {
  bucket = aws_s3_bucket.kops.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "kops" {
  bucket = aws_s3_bucket.kops.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "kops" {
  bucket                  = aws_s3_bucket.kops.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_route53_zone" "app" {
  name = var.zone_name
  lifecycle { prevent_destroy = true }
}
output "kops_state_store" { value = "s3://${aws_s3_bucket.kops.id}" }
