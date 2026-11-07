terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

resource "aws_ecr_repository" "app" {
  for_each             = var.manage_legacy_ecr ? toset(["api", "web"]) : toset([])
  name                 = "agribridge-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
