locals { environments = toset(["staging", "production"]) }

resource "kubernetes_namespace_v1" "app" {
  for_each = local.environments
  metadata { name = "agribridge-${each.key}" }
}

resource "helm_release" "secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.20.4"
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 900
  # A previous timed-out install may leave the Helm release outside Terraform state.
  # Recover this project's existing, pinned release with an upgrade rather than reinstalling.
  upgrade_install = true
  values          = [yamlencode({ serviceAccount = { name = "external-secrets", annotations = { "eks.amazonaws.com/role-arn" = var.platform.secrets_role } } })]
}

resource "helm_release" "ingress" {
  name             = "nginx-ingress"
  chart            = "oci://ghcr.io/nginx/charts/nginx-ingress"
  version          = "2.8.0"
  namespace        = "ingress"
  create_namespace = true
  timeout          = 900
  skip_crds        = true
  values           = [var.ingress_values]
}

data "kubernetes_service_v1" "ingress" {
  depends_on = [helm_release.ingress]
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "ingress"
  }
}

resource "aws_route53_record" "app" {
  for_each = local.environments
  zone_id  = var.platform.zone_id
  name     = "${each.key}.${var.platform.zone_name}"
  type     = "CNAME"
  ttl      = 60
  records  = [data.kubernetes_service_v1.ingress.status[0].load_balancer[0].ingress[0].hostname]
}

resource "helm_release" "monitoring" {
  depends_on       = [kubernetes_storage_class_v1.gp3]
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "79.8.2"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900
  values           = [var.monitoring_values]
}

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

resource "helm_release" "logs" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  version          = "0.53.0"
  namespace        = "logging"
  create_namespace = true
  values           = [var.logging_values]
}
