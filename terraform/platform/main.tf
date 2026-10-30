module "platform" {
  source            = "../modules/kubernetes-platform"
  platform          = var.platform
  monitoring_values = file("${path.module}/../../monitoring/prometheus-values.yaml")
  logging_values = templatefile("${path.module}/../../monitoring/fluent-bit-values.yaml.tftpl", {
    role   = var.platform.logs_role
    region = var.platform.region
  })
}
