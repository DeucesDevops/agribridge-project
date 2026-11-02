terraform {
  backend "s3" {}
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.expected_account_id]
}

provider "aws" {
  alias               = "files"
  region              = "us-east-1"
  allowed_account_ids = [var.expected_account_id]
}

module "cluster" {
  source = "../generated/kops"
  providers = {
    aws       = aws
    aws.files = aws.files
  }
}
