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
        "${var.github_immutable_subject_prefix}:ref:refs/heads/main",
        "${var.github_immutable_subject_prefix}:environment:qa",
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
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = [aws_eks_cluster.this.arn]
    }]
  })
}

locals {
  oidc_issuer_url  = aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_issuer_host = trimprefix(local.oidc_issuer_url, "https://")
}

data "aws_iam_policy_document" "irsa_assume" {
  for_each = local.irsa_trust

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
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

resource "aws_iam_role" "load_balancer" {
  name               = "agribridge-load-balancer"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["load_balancer"].json
}

resource "aws_iam_policy" "load_balancer" {
  name   = "agribridge-load-balancer"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role_policy_attachment" "load_balancer" {
  role       = aws_iam_role.load_balancer.name
  policy_arn = aws_iam_policy.load_balancer.arn
}

resource "aws_iam_role" "ebs_csi" {
  name               = "agribridge-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["ebs_csi"].json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "backup_production" {
  name               = "agribridge-backup-production"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["backup_production"].json
}

resource "aws_iam_role" "backup_qa" {
  name               = "agribridge-backup-qa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["backup_qa"].json
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

resource "aws_iam_role_policy" "backup_qa" {
  name   = "agribridge-backup-qa"
  role   = aws_iam_role.backup_qa.id
  policy = data.aws_iam_policy_document.backup.json
}
