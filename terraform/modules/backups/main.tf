resource "aws_s3_bucket" "backups" {
  bucket = "agribridge-backups-${var.account_id}"
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
  for_each           = var.environments
  name               = "agribridge-${each.key}-backup"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = "arn:aws:iam::${var.account_id}:oidc-provider/${var.oidc}" }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${var.oidc}:sub" = "system:serviceaccount:agribridge-${each.key}:agribridge-backup", "${var.oidc}:aud" = var.workload_token_audience } } }] })
}

resource "aws_iam_role_policy" "backup" {
  for_each = var.environments
  role     = aws_iam_role.backup[each.key].id
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.backups.arn}/${each.key}/*" }] })
}
