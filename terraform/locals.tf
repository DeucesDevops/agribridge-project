locals {
  github_oidc_provider_arn = (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : var.github_oidc_provider_arn
  )

  # Secret names consumed by the Helm chart. Keep helm/agribridge/values-*.yaml in step with these.
  environments = {
    qa         = "agribridge/qa"
    production = "agribridge/production"
  }

  secret_keys = ["PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"]
}
