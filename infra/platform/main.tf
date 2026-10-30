terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
  }
}
variable "platform" { type = map(string) }
provider "aws" { region = var.platform.region }
variable "kubeconfig_path" { type = string }
provider "helm" {
  kubernetes = { config_path = var.kubeconfig_path }
}
provider "kubernetes" { config_path = var.kubeconfig_path }
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
  values           = [yamlencode({ serviceAccount = { name = "external-secrets", annotations = { "eks.amazonaws.com/role-arn" = var.platform.secrets_role } } })]
}
resource "helm_release" "ingress" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "37.4.0"
  namespace        = "ingress"
  create_namespace = true
  timeout          = 900
  values = [yamlencode({
    deployment = { replicas = 2 },
    service = { annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external",
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance",
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing",
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"        = var.platform.certificate_arn,
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"       = "443"
    } },
    ports = { web = { redirections = { entryPoint = { to = "websecure", scheme = "https", permanent = true } } }, websecure = { tls = { enabled = false } } }
  })]
}
data "kubernetes_service_v1" "ingress" {
  depends_on = [helm_release.ingress]
  metadata {
    name      = "traefik"
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
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "79.8.2"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900
  values           = [yamlencode({ grafana = { enabled = true, persistence = { enabled = true, storageClassName = "agribridge-gp3", size = "2Gi" } }, prometheus = { prometheusSpec = { retention = "7d", storageSpec = { volumeClaimTemplate = { spec = { storageClassName = "agribridge-gp3", accessModes = ["ReadWriteOnce"], resources = { requests = { storage = "10Gi" } } } } }, serviceMonitorSelectorNilUsesHelmValues = false, ruleSelectorNilUsesHelmValues = false } } })]
}
