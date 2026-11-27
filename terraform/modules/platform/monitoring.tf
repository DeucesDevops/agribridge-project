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

  values = [yamlencode(local.monitoring.loki)]

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
    yamlencode(local.monitoring.prometheus),
    yamlencode(local.grafana_values),
    yamlencode({
      additionalPrometheusRulesMap = {
        agribridge-api = local.api_alerts
      }
    }),
  ]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  depends_on = [
    helm_release.loki,
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

  values = [yamlencode(local.monitoring.promtail)]

  depends_on = [helm_release.loki]
}

# Grafana's sidecar loads every ConfigMap labeled grafana_dashboard=1.
resource "kubernetes_config_map_v1" "api_dashboard" {
  metadata {
    name      = "agribridge-api-dashboard"
    namespace = helm_release.monitoring.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "api.json" = local.api_dashboard
  }
}
