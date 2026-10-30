output "ingress_hostname" { value = data.kubernetes_service_v1.ingress.status[0].load_balancer[0].ingress[0].hostname }
output "app_urls" { value = { for environment in local.environments : environment => "https://${environment}.${var.platform.zone_name}" } }
