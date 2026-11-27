locals {
  external_secrets_file = yamldecode(file("${local.values_dir}/external-secrets/values.yaml"))
  external_secrets_values = merge(
    local.external_secrets_file,
    {
      serviceAccount = merge(
        try(local.external_secrets_file.serviceAccount, {}),
        {
          annotations = merge(
            try(local.external_secrets_file.serviceAccount.annotations, {}),
            {
              "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
            }
          )
        }
      )
    }
  )
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = local.chart_version.external_secrets
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [yamlencode(local.external_secrets_values)]
}
