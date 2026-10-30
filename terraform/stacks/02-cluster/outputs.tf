output "cluster_name" {
  value = module.cluster.cluster_name
}

output "iam_openid_connect_provider_arn" {
  value = module.cluster.iam_openid_connect_provider_arn
}

output "iam_openid_connect_provider_issuer" {
  value = module.cluster.iam_openid_connect_provider_issuer
}

output "kube-system-aws-cloud-controller-manager_role_arn" {
  value = module.cluster.kube-system-aws-cloud-controller-manager_role_arn
}

output "kube-system-aws-cloud-controller-manager_role_name" {
  value = module.cluster.kube-system-aws-cloud-controller-manager_role_name
}

output "kube-system-aws-load-balancer-controller_role_arn" {
  value = module.cluster.kube-system-aws-load-balancer-controller_role_arn
}

output "kube-system-aws-load-balancer-controller_role_name" {
  value = module.cluster.kube-system-aws-load-balancer-controller_role_name
}

output "kube-system-aws-node-termination-handler_role_arn" {
  value = module.cluster.kube-system-aws-node-termination-handler_role_arn
}

output "kube-system-aws-node-termination-handler_role_name" {
  value = module.cluster.kube-system-aws-node-termination-handler_role_name
}

output "kube-system-dns-controller_role_arn" {
  value = module.cluster.kube-system-dns-controller_role_arn
}

output "kube-system-dns-controller_role_name" {
  value = module.cluster.kube-system-dns-controller_role_name
}

output "kube-system-ebs-csi-controller-sa_role_arn" {
  value = module.cluster.kube-system-ebs-csi-controller-sa_role_arn
}

output "kube-system-ebs-csi-controller-sa_role_name" {
  value = module.cluster.kube-system-ebs-csi-controller-sa_role_name
}

output "master_autoscaling_group_ids" {
  value = module.cluster.master_autoscaling_group_ids
}

output "master_security_group_ids" {
  value = module.cluster.master_security_group_ids
}

output "masters_role_arn" {
  value = module.cluster.masters_role_arn
}

output "masters_role_name" {
  value = module.cluster.masters_role_name
}

output "node_autoscaling_group_ids" {
  value = module.cluster.node_autoscaling_group_ids
}

output "node_security_group_ids" {
  value = module.cluster.node_security_group_ids
}

output "node_subnet_ids" {
  value = module.cluster.node_subnet_ids
}

output "nodes_role_arn" {
  value = module.cluster.nodes_role_arn
}

output "nodes_role_name" {
  value = module.cluster.nodes_role_name
}

output "region" {
  value = module.cluster.region
}

output "route_table_public_id" {
  value = module.cluster.route_table_public_id
}

output "subnet_us-east-1a_id" {
  value = module.cluster.subnet_us-east-1a_id
}

output "subnet_us-east-1b_id" {
  value = module.cluster.subnet_us-east-1b_id
}

output "vpc_cidr_block" {
  value = module.cluster.vpc_cidr_block
}

output "vpc_id" {
  value = module.cluster.vpc_id
}

output "vpc_ipv6_cidr_block" {
  value = module.cluster.vpc_ipv6_cidr_block
}

output "vpc_ipv6_cidr_length" {
  value = module.cluster.vpc_ipv6_cidr_length
}
