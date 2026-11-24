resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = local.chart_version.external_dns
  namespace        = "external-dns"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [yamlencode({
    provider      = { name = "aws" }
    policy        = "upsert-only"
    sources       = ["ingress"]
    txtOwnerId    = "agribridge"
    domainFilters = [var.zone_name]
    env = [{
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }]
    serviceAccount = {
      create = true
      name   = "external-dns"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.external_dns_role_arn
      }
    }
  })]
}
