module "platform" {
  source = "./modules/platform"
  count  = var.install_platform ? 1 : 0

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  region                    = var.region
  zone_name                 = var.zone_name
  certificate_arn           = aws_acm_certificate_validation.app.certificate_arn
  grafana_hostname          = local.grafana_hostname
  grafana_admin_password    = random_password.grafana.result
  external_secrets_role_arn = aws_iam_role.external_secrets.arn
  external_dns_role_arn     = aws_iam_role.external_dns.arn

  depends_on = [module.kops]
}
