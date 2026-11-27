terraform {
  required_version = ">= 1.10"

  # Local state. This root creates the bucket the production environment uses,
  # so it cannot store its own state there. *.tfstate is gitignored.
  # Environment backends lock with the S3 native lockfile (use_lockfile = true).
  # This root does not create a DynamoDB lock table.
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
