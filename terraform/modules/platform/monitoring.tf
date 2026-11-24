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
