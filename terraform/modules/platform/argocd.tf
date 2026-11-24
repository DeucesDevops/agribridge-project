resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = local.chart_version.argocd
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 900

  values = [
    file("${local.values_dir}/argocd-values.yaml"),
    yamlencode(local.argocd_values),
  ]
}

resource "helm_release" "agribridge_application" {
  name             = "agribridge-application"
  chart            = "${path.module}/../../../helm/agribridge-application"
  namespace        = "argocd"
  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = 300

  values = [yamlencode({
    repoURL              = "https://github.com/${var.github_repository}.git"
    targetRevision       = "main"
    hostname             = var.production_hostname
    region               = var.region
    certificateArn       = var.certificate_arn
    backupBucket         = var.backup_bucket
    backupRoleArn        = var.backup_role_arn
    destinationNamespace = "agribridge-production"
  })]

  depends_on = [helm_release.argocd]
}
