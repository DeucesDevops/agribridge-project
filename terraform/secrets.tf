resource "aws_kms_key" "secrets" {
  description             = "AgriBridge application secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/agribridge-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "random_password" "app" {
  for_each = {
    for item in setproduct(keys(local.environments), local.secret_keys) :
    "${item[0]}-${item[1]}" => item
  }

  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  for_each = local.environments

  name                    = each.value
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each = local.environments

  secret_id = aws_secretsmanager_secret.app[each.key].id
  secret_string = jsonencode({
    for key in local.secret_keys : key => random_password.app["${each.key}-${key}"].result
  })
}

resource "random_password" "grafana" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "grafana" {
  name                    = "agribridge/grafana"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    admin_user     = "admin"
    admin_password = random_password.grafana.result
  })
}
