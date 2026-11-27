data "aws_iam_policy_document" "irsa_assume" {
  for_each = local.irsa_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_issuer_host}:aud"
      values   = ["amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles

  name               = each.value.name
  assume_role_policy = data.aws_iam_policy_document.irsa_assume[each.key].json
}

data "aws_iam_policy_document" "backup" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.backup_bucket_arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${var.backup_bucket_arn}/*"]
  }
}

locals {
  irsa_policy_json = {
    external_secrets = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
          ]
          Resource = var.app_secret_arns
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = [var.kms_key_arn]
        },
      ]
    })
    external_dns = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["route53:ChangeResourceRecordSets"]
          Resource = [var.zone_arn]
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
    backup_production = data.aws_iam_policy_document.backup.json
  }
}

resource "aws_iam_role_policy" "irsa" {
  for_each = local.irsa_roles

  name   = each.value.name
  role   = aws_iam_role.irsa[each.key].id
  policy = local.irsa_policy_json[each.key]
}
