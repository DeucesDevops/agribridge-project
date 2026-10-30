module "bootstrap" {
  source            = "../modules/bootstrap"
  kops_state_bucket = var.kops_state_bucket
  zone_name         = var.zone_name
}
