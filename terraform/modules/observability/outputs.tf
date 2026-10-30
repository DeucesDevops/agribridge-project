output "logs_role" { value = aws_iam_role.logs.arn }
output "log_group" { value = aws_cloudwatch_log_group.app.name }
