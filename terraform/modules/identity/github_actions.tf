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

    # A job on main uses the ref subject.
    # A job that names the production environment uses the environment subject.
    # The image-tag job does not assume this role. The subjects stay so a
    # protected production job can still export a kubeconfig.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:environment:production",
        "${var.github_immutable_subject_prefix}:ref:refs/heads/main",
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
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = [var.kops_state_bucket_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${var.kops_state_bucket_arn}/*"]
      },
      {
        # kops export kubeconfig looks up regions and zones before reading the state store.
        Effect   = "Allow"
        Action   = ["ec2:DescribeRegions", "ec2:DescribeAvailabilityZones"]
        Resource = ["*"]
      },
    ]
  })
}
