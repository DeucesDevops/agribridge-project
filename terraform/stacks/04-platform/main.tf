terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
  }
}

provider "aws" { region = var.platform.region }
provider "helm" {
  kubernetes = { config_path = var.kubeconfig_path }
}
provider "kubernetes" { config_path = var.kubeconfig_path }

module "platform" {
  source   = "../../modules/kubernetes-platform"
  platform = var.platform
  ingress_values = templatefile("${path.module}/../../../kops/nginx-ingress-values.yaml.tftpl", {
    certificate_arn = var.platform.certificate_arn
  })
  monitoring_values = file("${path.module}/../../../monitoring/prometheus-values.yaml")
  logging_values = templatefile("${path.module}/../../../monitoring/fluent-bit-values.yaml.tftpl", {
    role   = var.platform.logs_role
    region = var.platform.region
  })
}
