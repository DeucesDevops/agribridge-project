output "bucket_name" {
  description = "Terraform state bucket. environments/production/backend.hcl and environments/dev/backend.hcl point at this name."
  value       = aws_s3_bucket.state.bucket
}

output "region" {
  description = "Region of the Terraform state bucket."
  value       = var.region
}
