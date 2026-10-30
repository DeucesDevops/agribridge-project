output "pipeline_role" { value = module.github_delivery.role_arn }
output "platform" {
  value = {
    region          = var.region
    certificate_arn = module.tls.certificate_arn
    zone_id         = data.aws_route53_zone.app.zone_id
    zone_name       = var.zone_name
    secrets_role    = module.runtime_secrets.role_arn
    logs_role       = module.observability.logs_role
  }
}

output "registry_namespace" { value = var.dockerhub_username }
