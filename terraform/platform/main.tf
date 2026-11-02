terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
  }
}

provider "aws" {
  region              = var.platform.region
  allowed_account_ids = [var.expected_account_id]
}
provider "helm" {
  kubernetes = { config_path = var.kubeconfig_path }
}
provider "kubernetes" { config_path = var.kubeconfig_path }

module "platform" {
  source                 = "../modules/kubernetes-platform"
  platform               = var.platform
  enable_legacy_pipeline = var.enable_legacy_pipeline
  enable_argocd          = var.enable_argocd
  argocd_values          = file("${path.module}/../../argocd/argocd-values.yaml")
  argocd_bootstrap_chart = abspath("${path.module}/../../helm/argocd-bootstrap")
  argocd_bootstrap_values = yamlencode({
    resources = [
      yamldecode(file("${path.module}/../../argocd/project.yaml")),
      yamldecode(file("${path.module}/../../argocd/staging-application.yaml")),
      yamldecode(file("${path.module}/../../argocd/production-application.yaml")),
    ]
  })
  ingress_values = templatefile("${path.module}/../../kubedefs/nginx-ingress-values.yaml.tftpl", {
    certificate_arn = var.platform.certificate_arn
  })
  monitoring_values = file("${path.module}/../../monitoring/prometheus-values.yaml")
  logging_values = templatefile("${path.module}/../../monitoring/fluent-bit-values.yaml.tftpl", {
    role   = var.platform.logs_role
    region = var.platform.region
  })
}
