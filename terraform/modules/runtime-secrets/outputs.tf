output "secret_arns" { value = { for e, s in aws_secretsmanager_secret.app : e => s.arn } }
output "role_arn" { value = aws_iam_role.secrets.arn }
