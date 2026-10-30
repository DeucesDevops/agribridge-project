output "bucket" { value = aws_s3_bucket.state.id }
output "discovery_store" { value = "s3://${aws_s3_bucket.discovery.id}" }
output "kops_state_store" { value = "s3://${aws_s3_bucket.kops.id}" }
