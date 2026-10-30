# Read-only fleet diagnostics use SSM; port 22 remains closed.
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = "nodes.${var.cluster_name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
