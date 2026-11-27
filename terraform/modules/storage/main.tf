data "aws_caller_identity" "current" {}

locals {
  backup_bucket_name = (
    var.backup_bucket != ""
    ? var.backup_bucket
    : "agribridge-backups-${data.aws_caller_identity.current.account_id}"
  )
}
