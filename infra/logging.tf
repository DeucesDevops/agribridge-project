resource "aws_cloudwatch_log_group" "app" {
  name              = "/agribridge/containers"
  retention_in_days = 14
}
resource "aws_iam_role" "logs" {
  name               = "agribridge-logs"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc}" }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${local.oidc}:sub" = "system:serviceaccount:logging:fluent-bit", "${local.oidc}:aud" = "sts.amazonaws.com" } } }] })
}
resource "aws_iam_role_policy" "logs" {
  role   = aws_iam_role.logs.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.app.arn}:*" }] })
}
