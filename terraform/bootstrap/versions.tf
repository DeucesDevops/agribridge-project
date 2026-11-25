terraform {
  required_version = ">= 1.10"

  # Local state. This root creates the bucket the production environment uses,
  # so it cannot store its own state there. *.tfstate is gitignored.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
