terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" { region = var.region }

module "bootstrap" {
  source            = "../../modules/bootstrap"
  kops_state_bucket = var.kops_state_bucket
  zone_name         = var.zone_name
}
