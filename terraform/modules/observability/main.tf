resource "aws_cloudwatch_log_group" "app" {
  name              = "/agribridge/containers"
  retention_in_days = 14
}

resource "aws_iam_role" "logs" {
  name               = "agribridge-logs"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = "arn:aws:iam::${var.account_id}:oidc-provider/${var.oidc}" }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${var.oidc}:sub" = "system:serviceaccount:logging:fluent-bit", "${var.oidc}:aud" = var.workload_token_audience } } }] })
}

resource "aws_iam_role_policy" "logs" {
  role   = aws_iam_role.logs.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.app.arn}:*" }] })
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = "nodes.${var.cluster_name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
