provider "aws" {
  region              = var.region
  allowed_account_ids = [var.expected_account_id]
}
