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
        "repo:${var.github_repository}:environment:qa",
        "repo:${var.github_repository}:environment:production",
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
    ]
  })
}

locals {
  oidc_issuer_url = (
    var.oidc_issuer_url != ""
    ? var.oidc_issuer_url
    : "https://${var.discovery_bucket}.s3.${var.region}.amazonaws.com"
  )
  oidc_issuer_host = trimprefix(local.oidc_issuer_url, "https://")
}

# kOps creates this provider when enableAWSOIDCProvider is true.
# The audience is amazonaws.com, which is the kOps pod-identity webhook default.
data "aws_iam_openid_connect_provider" "kops" {
  count = var.attach_irsa ? 1 : 0
  url   = local.oidc_issuer_url
}

data "aws_iam_policy_document" "external_secrets_assume" {
  count = var.attach_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.kops[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}

data "aws_iam_policy_document" "external_dns_assume" {
  count = var.attach_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.kops[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  count              = var.attach_irsa ? 1 : 0
  name               = "agribridge-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume[0].json
}

resource "aws_iam_role_policy" "external_secrets" {
  count = var.attach_irsa ? 1 : 0
  name  = "agribridge-external-secrets"
  role  = aws_iam_role.external_secrets[0].id

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
  count              = var.attach_irsa ? 1 : 0
  name               = "agribridge-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume[0].json
}

resource "aws_iam_role_policy" "external_dns" {
  count = var.attach_irsa ? 1 : 0
  name  = "agribridge-external-dns"
  role  = aws_iam_role.external_dns[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = [data.aws_route53_zone.app.arn]
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
