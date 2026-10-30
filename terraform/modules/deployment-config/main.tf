resource "aws_ssm_parameter" "deployment" {
  for_each = var.environments
  name     = "/agribridge/${each.key}/deployment"
  type     = "String"
  value = jsonencode({
    region         = var.region, namespace = "agribridge-${each.key}", hostname = "${each.key}.${var.zone_name}",
    api_repository = var.repositories["api"], web_repository = var.repositories["web"],
    secret_arn     = var.secret_arns[each.key],
    backup_bucket  = var.backup_bucket, backup_role = var.backup_roles[each.key],
    deploy_secret  = "agribridge-${each.key}/deploy"
  })
}
