data "tls_certificate" "github" {
  count = var.create_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[0].certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Image push runs on main and uses the ref subject.
    # Deploy jobs use a GitHub environment, so their subject is the environment name.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:environment:production",
        "${var.github_immutable_subject_prefix}:ref:refs/heads/main",
        "${var.github_immutable_subject_prefix}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github" {
  name               = "agribridge-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

resource "aws_iam_role_policy" "github" {
  name = "agribridge-github-actions"
  role = aws_iam_role.github.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = [aws_s3_bucket.kops_state.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.kops_state.arn}/*"]
      },
      {
        # kops export kubeconfig looks up regions and zones before reading the state store.
        Effect   = "Allow"
        Action   = ["ec2:DescribeRegions", "ec2:DescribeAvailabilityZones"]
        Resource = ["*"]
      },
    ]
  })
}

locals {
  oidc_issuer_host = module.kops.iam_openid_connect_provider_issuer
}

data "aws_iam_policy_document" "irsa_assume" {
  for_each = local.irsa_trust

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.kops.iam_openid_connect_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "agribridge-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["external_secrets"].json
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "agribridge-external-secrets"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
        ]
        Resource = [for secret in aws_secretsmanager_secret.app : secret.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [aws_kms_key.secrets.arn]
      },
    ]
  })
}

resource "aws_iam_role" "external_dns" {
  name               = "agribridge-external-dns"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["external_dns"].json
}

resource "aws_iam_role_policy" "external_dns" {
  name = "agribridge-external-dns"
  role = aws_iam_role.external_dns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = [aws_route53_zone.app.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "backup_production" {
  name               = "agribridge-backup-production"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["backup_production"].json
}

data "aws_iam_policy_document" "backup" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${aws_s3_bucket.backups.arn}/*"]
  }
}

resource "aws_iam_role_policy" "backup_production" {
  name   = "agribridge-backup-production"
  role   = aws_iam_role.backup_production.id
  policy = data.aws_iam_policy_document.backup.json
}

