resource "helm_release" "logs" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  version          = "0.53.0"
  namespace        = "logging"
  create_namespace = true
  values = [yamlencode({
    serviceAccount = { name = "fluent-bit", annotations = { "eks.amazonaws.com/role-arn" = var.platform.logs_role } },
    config = {
      inputs  = "[INPUT]\n    Name tail\n    Path /var/log/containers/agribridge-*.log\n    multiline.parser docker, cri\n    Tag kube.*\n    Mem_Buf_Limit 5MB\n    Skip_Long_Lines On\n",
      filters = "[FILTER]\n    Name kubernetes\n    Match kube.*\n    Merge_Log On\n    Keep_Log Off\n",
      outputs = "[OUTPUT]\n    Name cloudwatch_logs\n    Match *\n    region ${var.platform.region}\n    log_group_name /agribridge/containers\n    log_stream_prefix k8s-\n    auto_create_group false\n"
    }
  })]
}
