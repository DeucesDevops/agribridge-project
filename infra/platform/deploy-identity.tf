resource "kubernetes_service_account_v1" "pipeline" {
  for_each = local.environments
  metadata {
    name      = "pipeline"
    namespace = kubernetes_namespace_v1.app[each.key].metadata[0].name
  }
}
resource "kubernetes_role_v1" "pipeline" {
  for_each = local.environments
  metadata {
    name      = "pipeline"
    namespace = kubernetes_namespace_v1.app[each.key].metadata[0].name
  }
  rule {
    api_groups = ["", "apps", "batch", "networking.k8s.io", "policy", "external-secrets.io", "monitoring.coreos.com"]
    resources  = ["configmaps", "secrets", "services", "serviceaccounts", "pods", "pods/log", "pods/exec", "persistentvolumeclaims", "deployments", "statefulsets", "replicasets", "jobs", "cronjobs", "ingresses", "networkpolicies", "poddisruptionbudgets", "externalsecrets", "secretstores", "servicemonitors", "prometheusrules"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}
resource "kubernetes_role_binding_v1" "pipeline" {
  for_each = local.environments
  metadata {
    name      = "pipeline"
    namespace = kubernetes_namespace_v1.app[each.key].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.pipeline[each.key].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "pipeline"
    namespace = kubernetes_namespace_v1.app[each.key].metadata[0].name
  }
}
resource "kubernetes_secret_v1" "pipeline" {
  for_each = local.environments
  metadata {
    name        = "pipeline-token"
    namespace   = kubernetes_namespace_v1.app[each.key].metadata[0].name
    annotations = { "kubernetes.io/service-account.name" = kubernetes_service_account_v1.pipeline[each.key].metadata[0].name }
  }
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}
resource "aws_secretsmanager_secret" "pipeline" {
  for_each = local.environments
  name     = "agribridge-${each.key}/deploy"
}
locals { kubeconfig = yamldecode(file(var.kubeconfig_path)) }
resource "aws_secretsmanager_secret_version" "pipeline" {
  for_each  = local.environments
  secret_id = aws_secretsmanager_secret.pipeline[each.key].id
  secret_string = jsonencode({
    apiVersion = "v1", kind = "Config", "current-context" = "deploy",
    clusters   = [{ name = "app", cluster = { server = "https://api.k8s.agribridge.deuces.dev", "certificate-authority-data" = base64encode(kubernetes_secret_v1.pipeline[each.key].data["ca.crt"]) } }],
    contexts   = [{ name = "deploy", context = { cluster = "app", user = "pipeline", namespace = "agribridge-${each.key}" } }],
    users      = [{ name = "pipeline", user = { token = kubernetes_secret_v1.pipeline[each.key].data.token } }]
  })
}
resource "kubernetes_storage_class_v1" "gp3" {
  metadata { name = "agribridge-gp3" }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters             = { type = "gp3", encrypted = "true" }
}
