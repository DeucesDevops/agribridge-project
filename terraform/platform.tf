module "platform" {
  source = "./modules/platform"
  count  = var.install_platform ? 1 : 0

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  cluster_name              = aws_eks_cluster.this.name
  region                    = var.region
  vpc_id                    = aws_vpc.this.id
  zone_name                 = var.zone_name
  certificate_arn           = aws_acm_certificate_validation.app.certificate_arn
  grafana_hostname          = local.grafana_hostname
  grafana_admin_password    = random_password.grafana.result
  external_secrets_role_arn = aws_iam_role.external_secrets.arn
  external_dns_role_arn     = aws_iam_role.external_dns.arn
  load_balancer_role_arn    = aws_iam_role.load_balancer.arn

  depends_on = [
    aws_eks_node_group.nodes,
    aws_eks_addon.ebs_csi,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
  ]
}
