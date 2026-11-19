locals {
  values_dir = "${path.module}/../../../platform"

  chart_version = {
    external_secrets = "2.15.0"
    external_dns     = "1.23.0"
    loki             = "7.6.0"
    tempo            = "1.24.4"
    monitoring       = "93.3.1"
    promtail         = "6.17.1"
  }

  storage_class = yamldecode(file("${local.values_dir}/storage-class.yaml"))

  grafana_values = {
    grafana = {
      "grafana.ini" = {
        server = {
          root_url = "https://${var.grafana_hostname}"
        }
        users = {
          allow_sign_up = false
        }
        "auth.anonymous" = {
          enabled = false
        }
      }
      # Calico pod IPs are not routable from the VPC, so the ALB targets the
      # node port (same as the app ingress) instead of pod IPs.
      service = {
        type = "NodePort"
      }
      ingress = {
        enabled          = true
        ingressClassName = "alb"
        path             = "/"
        pathType         = "Prefix"
        hosts            = [var.grafana_hostname]
        annotations = {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "instance"
          "alb.ingress.kubernetes.io/group.name"       = "agribridge"
          "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
          "alb.ingress.kubernetes.io/certificate-arn"  = var.certificate_arn
          "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
          "alb.ingress.kubernetes.io/success-codes"    = "200"
          "external-dns.alpha.kubernetes.io/hostname"  = var.grafana_hostname
        }
      }
    }
  }
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name        = local.storage_class.metadata.name
    annotations = try(local.storage_class.metadata.annotations, {})
  }

  storage_provisioner    = local.storage_class.provisioner
  reclaim_policy         = local.storage_class.reclaimPolicy
  volume_binding_mode    = local.storage_class.volumeBindingMode
  allow_volume_expansion = local.storage_class.allowVolumeExpansion
  parameters             = local.storage_class.parameters
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

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = "external-secrets"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
      }
    }
  })]
}

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

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = local.chart_version.loki
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 900

  values = [file("${local.values_dir}/loki-values.yaml")]

  depends_on = [kubernetes_storage_class_v1.gp3]
}

resource "helm_release" "tempo" {
  name             = "tempo"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "tempo"
  version          = local.chart_version.tempo
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 900

  values = [file("${local.values_dir}/tempo-values.yaml")]

  depends_on = [kubernetes_storage_class_v1.gp3]
}

resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = local.chart_version.monitoring
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 900

  values = [
    file("${local.values_dir}/prometheus-values.yaml"),
    yamlencode(local.grafana_values),
  ]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  depends_on = [
    helm_release.loki,
    helm_release.tempo,
    kubernetes_storage_class_v1.gp3,
  ]
}

resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = local.chart_version.promtail
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [file("${local.values_dir}/promtail-values.yaml")]

  depends_on = [helm_release.loki]
}
