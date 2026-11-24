data "tls_certificate" "github" {
  for_each = var.create_github_oidc_provider ? toset(["github"]) : toset([])

  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  for_each = var.create_github_oidc_provider ? toset(["github"]) : toset([])

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[each.key].certificates[0].sha1_fingerprint]
}
