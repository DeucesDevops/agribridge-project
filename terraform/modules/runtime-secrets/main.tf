terraform {
  required_version = ">= 1.10"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
  }
}

resource "random_password" "secret" {
  for_each = toset(flatten([for environment in var.environments : [for key in ["PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"] : "${environment}-${key}"]]))
  length   = 40
  special  = false
}

resource "aws_secretsmanager_secret" "app" {
  for_each = var.environments
  name     = "agribridge-${each.key}/runtime"
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each      = var.environments
  secret_id     = aws_secretsmanager_secret.app[each.key].id
  secret_string = jsonencode({ for k in ["PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"] : k => random_password.secret["${each.key}-${k}"].result })
}

resource "aws_iam_role" "secrets" {
  name               = "agribridge-external-secrets"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = "arn:aws:iam::${var.account_id}:oidc-provider/${var.oidc}" }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${var.oidc}:sub" = "system:serviceaccount:external-secrets:external-secrets", "${var.oidc}:aud" = var.workload_token_audience } } }] })
}

resource "aws_iam_role_policy" "secrets" {
  role   = aws_iam_role.secrets.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = [for s in aws_secretsmanager_secret.app : s.arn] }] })
}
