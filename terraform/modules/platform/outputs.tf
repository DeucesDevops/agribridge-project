output "release_names" {
  description = "Helm releases installed by this module."
  value = [
    helm_release.external_secrets.name,
    helm_release.external_dns.name,
    helm_release.loki.name,
    helm_release.monitoring.name,
    helm_release.promtail.name,
    helm_release.argocd.name,
    helm_release.agribridge_application.name,
  ]
}
