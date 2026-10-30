locals {
  cluster_name                                       = "k8s.agribridge.deuces.dev"
  iam_openid_connect_provider_arn                    = aws_iam_openid_connect_provider.k8s-agribridge-deuces-dev.arn
  iam_openid_connect_provider_issuer                 = "agribridge-oidc-237258628535.s3.us-east-1.amazonaws.com"
  kube-system-aws-cloud-controller-manager_role_arn  = aws_iam_role.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp.arn
  kube-system-aws-cloud-controller-manager_role_name = aws_iam_role.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp.name
  kube-system-aws-load-balancer-controller_role_arn  = aws_iam_role.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3.arn
  kube-system-aws-load-balancer-controller_role_name = aws_iam_role.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3.name
  kube-system-aws-node-termination-handler_role_arn  = aws_iam_role.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf.arn
  kube-system-aws-node-termination-handler_role_name = aws_iam_role.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf.name
  kube-system-dns-controller_role_arn                = aws_iam_role.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev.arn
  kube-system-dns-controller_role_name               = aws_iam_role.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev.name
  kube-system-ebs-csi-controller-sa_role_arn         = aws_iam_role.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev.arn
  kube-system-ebs-csi-controller-sa_role_name        = aws_iam_role.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev.name
  master_autoscaling_group_ids                       = [aws_autoscaling_group.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev.id]
  master_security_group_ids                          = [aws_security_group.masters-k8s-agribridge-deuces-dev.id]
  masters_role_arn                                   = aws_iam_role.masters-k8s-agribridge-deuces-dev.arn
  masters_role_name                                  = aws_iam_role.masters-k8s-agribridge-deuces-dev.name
  node_autoscaling_group_ids                         = [aws_autoscaling_group.nodes-us-east-1a-k8s-agribridge-deuces-dev.id, aws_autoscaling_group.nodes-us-east-1b-k8s-agribridge-deuces-dev.id]
  node_security_group_ids                            = [aws_security_group.nodes-k8s-agribridge-deuces-dev.id]
  node_subnet_ids                                    = [aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id, aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id]
  nodes_role_arn                                     = aws_iam_role.nodes-k8s-agribridge-deuces-dev.arn
  nodes_role_name                                    = aws_iam_role.nodes-k8s-agribridge-deuces-dev.name
  region                                             = "us-east-1"
  route_table_public_id                              = aws_route_table.k8s-agribridge-deuces-dev.id
  subnet_us-east-1a_id                               = aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id
  subnet_us-east-1b_id                               = aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id
  vpc_cidr_block                                     = aws_vpc.k8s-agribridge-deuces-dev.cidr_block
  vpc_id                                             = aws_vpc.k8s-agribridge-deuces-dev.id
  vpc_ipv6_cidr_block                                = aws_vpc.k8s-agribridge-deuces-dev.ipv6_cidr_block
  vpc_ipv6_cidr_length                               = local.vpc_ipv6_cidr_block == "" ? null : tonumber(regex(".*/(\\d+)", local.vpc_ipv6_cidr_block)[0])
}

output "cluster_name" {
  value = "k8s.agribridge.deuces.dev"
}

output "iam_openid_connect_provider_arn" {
  value = aws_iam_openid_connect_provider.k8s-agribridge-deuces-dev.arn
}

output "iam_openid_connect_provider_issuer" {
  value = "agribridge-oidc-237258628535.s3.us-east-1.amazonaws.com"
}

output "kube-system-aws-cloud-controller-manager_role_arn" {
  value = aws_iam_role.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp.arn
}

output "kube-system-aws-cloud-controller-manager_role_name" {
  value = aws_iam_role.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp.name
}

output "kube-system-aws-load-balancer-controller_role_arn" {
  value = aws_iam_role.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3.arn
}

output "kube-system-aws-load-balancer-controller_role_name" {
  value = aws_iam_role.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3.name
}

output "kube-system-aws-node-termination-handler_role_arn" {
  value = aws_iam_role.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf.arn
}

output "kube-system-aws-node-termination-handler_role_name" {
  value = aws_iam_role.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf.name
}

output "kube-system-dns-controller_role_arn" {
  value = aws_iam_role.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev.arn
}

output "kube-system-dns-controller_role_name" {
  value = aws_iam_role.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev.name
}

output "kube-system-ebs-csi-controller-sa_role_arn" {
  value = aws_iam_role.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev.arn
}

output "kube-system-ebs-csi-controller-sa_role_name" {
  value = aws_iam_role.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev.name
}

output "master_autoscaling_group_ids" {
  value = [aws_autoscaling_group.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev.id]
}

output "master_security_group_ids" {
  value = [aws_security_group.masters-k8s-agribridge-deuces-dev.id]
}

output "masters_role_arn" {
  value = aws_iam_role.masters-k8s-agribridge-deuces-dev.arn
}

output "masters_role_name" {
  value = aws_iam_role.masters-k8s-agribridge-deuces-dev.name
}

output "node_autoscaling_group_ids" {
  value = [aws_autoscaling_group.nodes-us-east-1a-k8s-agribridge-deuces-dev.id, aws_autoscaling_group.nodes-us-east-1b-k8s-agribridge-deuces-dev.id]
}

output "node_security_group_ids" {
  value = [aws_security_group.nodes-k8s-agribridge-deuces-dev.id]
}

output "node_subnet_ids" {
  value = [aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id, aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id]
}

output "nodes_role_arn" {
  value = aws_iam_role.nodes-k8s-agribridge-deuces-dev.arn
}

output "nodes_role_name" {
  value = aws_iam_role.nodes-k8s-agribridge-deuces-dev.name
}

output "region" {
  value = "us-east-1"
}

output "route_table_public_id" {
  value = aws_route_table.k8s-agribridge-deuces-dev.id
}

output "subnet_us-east-1a_id" {
  value = aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id
}

output "subnet_us-east-1b_id" {
  value = aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id
}

output "vpc_cidr_block" {
  value = aws_vpc.k8s-agribridge-deuces-dev.cidr_block
}

output "vpc_id" {
  value = aws_vpc.k8s-agribridge-deuces-dev.id
}

output "vpc_ipv6_cidr_block" {
  value = aws_vpc.k8s-agribridge-deuces-dev.ipv6_cidr_block
}

output "vpc_ipv6_cidr_length" {
  value = local.vpc_ipv6_cidr_block == "" ? null : tonumber(regex(".*/(\\d+)", local.vpc_ipv6_cidr_block)[0])
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "files"
  region = "us-east-1"
}

resource "aws_autoscaling_group" "control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev" {
  enabled_metrics = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupMaxSize", "GroupMinSize", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  launch_template {
    id      = aws_launch_template.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev.id
    version = aws_launch_template.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev.latest_version
  }
  max_instance_lifetime = 0
  max_size              = 1
  metrics_granularity   = "1Minute"
  min_size              = 1
  name                  = "control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev"
  protect_from_scale_in = false
  tag {
    key                 = "KubernetesCluster"
    propagate_at_launch = true
    value               = "k8s.agribridge.deuces.dev"
  }
  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev"
  }
  tag {
    key                 = "aws-node-termination-handler/managed"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"
    propagate_at_launch = true
    value               = "control-plane-us-east-1a"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/kops-controller-pki"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/control-plane"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/exclude-from-external-load-balancers"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/role/control-plane"
    propagate_at_launch = true
    value               = "1"
  }
  tag {
    key                 = "k8s.io/role/master"
    propagate_at_launch = true
    value               = "1"
  }
  tag {
    key                 = "kops.k8s.io/instancegroup"
    propagate_at_launch = true
    value               = "control-plane-us-east-1a"
  }
  tag {
    key                 = "kubernetes.io/cluster/k8s.agribridge.deuces.dev"
    propagate_at_launch = true
    value               = "owned"
  }
  vpc_zone_identifier = [aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id]
}

resource "aws_autoscaling_group" "nodes-us-east-1a-k8s-agribridge-deuces-dev" {
  enabled_metrics = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupMaxSize", "GroupMinSize", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  launch_template {
    id      = aws_launch_template.nodes-us-east-1a-k8s-agribridge-deuces-dev.id
    version = aws_launch_template.nodes-us-east-1a-k8s-agribridge-deuces-dev.latest_version
  }
  max_instance_lifetime = 0
  max_size              = 1
  metrics_granularity   = "1Minute"
  min_size              = 1
  name                  = "nodes-us-east-1a.k8s.agribridge.deuces.dev"
  protect_from_scale_in = false
  tag {
    key                 = "KubernetesCluster"
    propagate_at_launch = true
    value               = "k8s.agribridge.deuces.dev"
  }
  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "nodes-us-east-1a.k8s.agribridge.deuces.dev"
  }
  tag {
    key                 = "aws-node-termination-handler/managed"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"
    propagate_at_launch = true
    value               = "nodes-us-east-1a"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/role/node"
    propagate_at_launch = true
    value               = "1"
  }
  tag {
    key                 = "kops.k8s.io/instancegroup"
    propagate_at_launch = true
    value               = "nodes-us-east-1a"
  }
  tag {
    key                 = "kubernetes.io/cluster/k8s.agribridge.deuces.dev"
    propagate_at_launch = true
    value               = "owned"
  }
  vpc_zone_identifier = [aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id]
}

resource "aws_autoscaling_group" "nodes-us-east-1b-k8s-agribridge-deuces-dev" {
  enabled_metrics = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupMaxSize", "GroupMinSize", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  launch_template {
    id      = aws_launch_template.nodes-us-east-1b-k8s-agribridge-deuces-dev.id
    version = aws_launch_template.nodes-us-east-1b-k8s-agribridge-deuces-dev.latest_version
  }
  max_instance_lifetime = 0
  max_size              = 1
  metrics_granularity   = "1Minute"
  min_size              = 1
  name                  = "nodes-us-east-1b.k8s.agribridge.deuces.dev"
  protect_from_scale_in = false
  tag {
    key                 = "KubernetesCluster"
    propagate_at_launch = true
    value               = "k8s.agribridge.deuces.dev"
  }
  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "nodes-us-east-1b.k8s.agribridge.deuces.dev"
  }
  tag {
    key                 = "aws-node-termination-handler/managed"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"
    propagate_at_launch = true
    value               = "nodes-us-east-1b"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node"
    propagate_at_launch = true
    value               = ""
  }
  tag {
    key                 = "k8s.io/role/node"
    propagate_at_launch = true
    value               = "1"
  }
  tag {
    key                 = "kops.k8s.io/instancegroup"
    propagate_at_launch = true
    value               = "nodes-us-east-1b"
  }
  tag {
    key                 = "kubernetes.io/cluster/k8s.agribridge.deuces.dev"
    propagate_at_launch = true
    value               = "owned"
  }
  vpc_zone_identifier = [aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id]
}

resource "aws_autoscaling_lifecycle_hook" "control-plane-us-east-1a-NTHLifecycleHook" {
  autoscaling_group_name = aws_autoscaling_group.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev.id
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  name                   = "control-plane-us-east-1a-NTHLifecycleHook"
}

resource "aws_autoscaling_lifecycle_hook" "nodes-us-east-1a-NTHLifecycleHook" {
  autoscaling_group_name = aws_autoscaling_group.nodes-us-east-1a-k8s-agribridge-deuces-dev.id
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  name                   = "nodes-us-east-1a-NTHLifecycleHook"
}

resource "aws_autoscaling_lifecycle_hook" "nodes-us-east-1b-NTHLifecycleHook" {
  autoscaling_group_name = aws_autoscaling_group.nodes-us-east-1b-k8s-agribridge-deuces-dev.id
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  name                   = "nodes-us-east-1b-NTHLifecycleHook"
}

resource "aws_cloudwatch_event_rule" "k8s-agribridge-deuces-dev-ASGLifecycle" {
  event_pattern = file("${path.module}/data/aws_cloudwatch_event_rule_k8s.agribridge.deuces.dev-ASGLifecycle_event_pattern")
  name          = "k8s.agribridge.deuces.dev-ASGLifecycle"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev-ASGLifecycle"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_cloudwatch_event_rule" "k8s-agribridge-deuces-dev-InstanceScheduledChange" {
  event_pattern = file("${path.module}/data/aws_cloudwatch_event_rule_k8s.agribridge.deuces.dev-InstanceScheduledChange_event_pattern")
  name          = "k8s.agribridge.deuces.dev-InstanceScheduledChange"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev-InstanceScheduledChange"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_cloudwatch_event_rule" "k8s-agribridge-deuces-dev-InstanceStateChange" {
  event_pattern = file("${path.module}/data/aws_cloudwatch_event_rule_k8s.agribridge.deuces.dev-InstanceStateChange_event_pattern")
  name          = "k8s.agribridge.deuces.dev-InstanceStateChange"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev-InstanceStateChange"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_cloudwatch_event_rule" "k8s-agribridge-deuces-dev-SpotInterruption" {
  event_pattern = file("${path.module}/data/aws_cloudwatch_event_rule_k8s.agribridge.deuces.dev-SpotInterruption_event_pattern")
  name          = "k8s.agribridge.deuces.dev-SpotInterruption"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev-SpotInterruption"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_cloudwatch_event_target" "k8s-agribridge-deuces-dev-ASGLifecycle-Target" {
  arn  = aws_sqs_queue.k8s-agribridge-deuces-dev-nth.arn
  rule = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-ASGLifecycle.id
}

resource "aws_cloudwatch_event_target" "k8s-agribridge-deuces-dev-InstanceScheduledChange-Target" {
  arn  = aws_sqs_queue.k8s-agribridge-deuces-dev-nth.arn
  rule = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-InstanceScheduledChange.id
}

resource "aws_cloudwatch_event_target" "k8s-agribridge-deuces-dev-InstanceStateChange-Target" {
  arn  = aws_sqs_queue.k8s-agribridge-deuces-dev-nth.arn
  rule = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-InstanceStateChange.id
}

resource "aws_cloudwatch_event_target" "k8s-agribridge-deuces-dev-SpotInterruption-Target" {
  arn  = aws_sqs_queue.k8s-agribridge-deuces-dev-nth.arn
  rule = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-SpotInterruption.id
}

resource "aws_ebs_volume" "a-etcd-events-k8s-agribridge-deuces-dev" {
  availability_zone = "us-east-1a"
  encrypted         = true
  iops              = 3000
  size              = 20
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "a.etcd-events.k8s.agribridge.deuces.dev"
    "k8s.io/etcd/events"                              = "a/a"
    "k8s.io/role/control-plane"                       = "1"
    "k8s.io/role/master"                              = "1"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
  throughput = 125
  type       = "gp3"
}

resource "aws_ebs_volume" "a-etcd-main-k8s-agribridge-deuces-dev" {
  availability_zone = "us-east-1a"
  encrypted         = true
  iops              = 3000
  size              = 20
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "a.etcd-main.k8s.agribridge.deuces.dev"
    "k8s.io/etcd/main"                                = "a/a"
    "k8s.io/role/control-plane"                       = "1"
    "k8s.io/role/master"                              = "1"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
  throughput = 125
  type       = "gp3"
}

resource "aws_iam_instance_profile" "masters-k8s-agribridge-deuces-dev" {
  name = "masters.k8s.agribridge.deuces.dev"
  role = aws_iam_role.masters-k8s-agribridge-deuces-dev.name
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "masters.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_iam_instance_profile" "nodes-k8s-agribridge-deuces-dev" {
  name = "nodes.k8s.agribridge.deuces.dev"
  role = aws_iam_role.nodes-k8s-agribridge-deuces-dev.name
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "nodes.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_iam_openid_connect_provider" "k8s-agribridge-deuces-dev" {
  client_id_list = ["amazonaws.com"]
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280", "a9d53002e97e00e043244f3d170d6f4c414104fd"]
  url             = "https://agribridge-oidc-237258628535.s3.us-east-1.amazonaws.com"
}

resource "aws_iam_role" "aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp" {
  assume_role_policy = file("${path.module}/data/aws_iam_role_aws-cloud-controller-manager.kube-system.sa.k8s.agribridg-em0qfp_policy")
  name               = "aws-cloud-controller-manager.kube-system.sa.k8s.agribridg-em0qfp"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "aws-cloud-controller-manager.kube-system.sa.k8s.agribridg-em0qfp"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "service-account.kops.k8s.io/name"                = "aws-cloud-controller-manager"
    "service-account.kops.k8s.io/namespace"           = "kube-system"
  }
}

resource "aws_iam_role" "aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3" {
  assume_role_policy = file("${path.module}/data/aws_iam_role_aws-load-balancer-controller.kube-system.sa.k8s.agribridg-5s6ug3_policy")
  name               = "aws-load-balancer-controller.kube-system.sa.k8s.agribridg-5s6ug3"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "aws-load-balancer-controller.kube-system.sa.k8s.agribridg-5s6ug3"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "service-account.kops.k8s.io/name"                = "aws-load-balancer-controller"
    "service-account.kops.k8s.io/namespace"           = "kube-system"
  }
}

resource "aws_iam_role" "aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf" {
  assume_role_policy = file("${path.module}/data/aws_iam_role_aws-node-termination-handler.kube-system.sa.k8s.agribridg-5ejarf_policy")
  name               = "aws-node-termination-handler.kube-system.sa.k8s.agribridg-5ejarf"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "aws-node-termination-handler.kube-system.sa.k8s.agribridg-5ejarf"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "service-account.kops.k8s.io/name"                = "aws-node-termination-handler"
    "service-account.kops.k8s.io/namespace"           = "kube-system"
  }
}

resource "aws_iam_role" "dns-controller-kube-system-sa-k8s-agribridge-deuces-dev" {
  assume_role_policy = file("${path.module}/data/aws_iam_role_dns-controller.kube-system.sa.k8s.agribridge.deuces.dev_policy")
  name               = "dns-controller.kube-system.sa.k8s.agribridge.deuces.dev"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "dns-controller.kube-system.sa.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "service-account.kops.k8s.io/name"                = "dns-controller"
    "service-account.kops.k8s.io/namespace"           = "kube-system"
  }
}

resource "aws_iam_role" "ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev" {
  assume_role_policy = file("${path.module}/data/aws_iam_role_ebs-csi-controller-sa.kube-system.sa.k8s.agribridge.deuces.dev_policy")
  name               = "ebs-csi-controller-sa.kube-system.sa.k8s.agribridge.deuces.dev"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "ebs-csi-controller-sa.kube-system.sa.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "service-account.kops.k8s.io/name"                = "ebs-csi-controller-sa"
    "service-account.kops.k8s.io/namespace"           = "kube-system"
  }
}

resource "aws_iam_role" "masters-k8s-agribridge-deuces-dev" {
  assume_role_policy = file("${path.module}/data/aws_iam_role_masters.k8s.agribridge.deuces.dev_policy")
  name               = "masters.k8s.agribridge.deuces.dev"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "masters.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_iam_role" "nodes-k8s-agribridge-deuces-dev" {
  assume_role_policy = file("${path.module}/data/aws_iam_role_nodes.k8s.agribridge.deuces.dev_policy")
  name               = "nodes.k8s.agribridge.deuces.dev"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "nodes.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_iam_role_policy" "aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp" {
  name   = "aws-cloud-controller-manager.kube-system.sa.k8s.agribridg-em0qfp"
  policy = file("${path.module}/data/aws_iam_role_policy_aws-cloud-controller-manager.kube-system.sa.k8s.agribridg-em0qfp_policy")
  role   = aws_iam_role.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp.name
}

resource "aws_iam_role_policy" "aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3" {
  name   = "aws-load-balancer-controller.kube-system.sa.k8s.agribridg-5s6ug3"
  policy = file("${path.module}/data/aws_iam_role_policy_aws-load-balancer-controller.kube-system.sa.k8s.agribridg-5s6ug3_policy")
  role   = aws_iam_role.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3.name
}

resource "aws_iam_role_policy" "aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf" {
  name   = "aws-node-termination-handler.kube-system.sa.k8s.agribridg-5ejarf"
  policy = file("${path.module}/data/aws_iam_role_policy_aws-node-termination-handler.kube-system.sa.k8s.agribridg-5ejarf_policy")
  role   = aws_iam_role.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf.name
}

resource "aws_iam_role_policy" "dns-controller-kube-system-sa-k8s-agribridge-deuces-dev" {
  name   = "dns-controller.kube-system.sa.k8s.agribridge.deuces.dev"
  policy = file("${path.module}/data/aws_iam_role_policy_dns-controller.kube-system.sa.k8s.agribridge.deuces.dev_policy")
  role   = aws_iam_role.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev.name
}

resource "aws_iam_role_policy" "ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev" {
  name   = "ebs-csi-controller-sa.kube-system.sa.k8s.agribridge.deuces.dev"
  policy = file("${path.module}/data/aws_iam_role_policy_ebs-csi-controller-sa.kube-system.sa.k8s.agribridge.deuces.dev_policy")
  role   = aws_iam_role.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev.name
}

resource "aws_iam_role_policy" "masters-k8s-agribridge-deuces-dev" {
  name   = "masters.k8s.agribridge.deuces.dev"
  policy = file("${path.module}/data/aws_iam_role_policy_masters.k8s.agribridge.deuces.dev_policy")
  role   = aws_iam_role.masters-k8s-agribridge-deuces-dev.name
}

resource "aws_iam_role_policy" "nodes-k8s-agribridge-deuces-dev" {
  name   = "nodes.k8s.agribridge.deuces.dev"
  policy = file("${path.module}/data/aws_iam_role_policy_nodes.k8s.agribridge.deuces.dev_policy")
  role   = aws_iam_role.nodes-k8s-agribridge-deuces-dev.name
}

resource "aws_internet_gateway" "k8s-agribridge-deuces-dev" {
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
  vpc_id = aws_vpc.k8s-agribridge-deuces-dev.id
}

resource "aws_launch_template" "control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev" {
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      iops                  = 3000
      throughput            = 125
      volume_size           = 64
      volume_type           = "gp3"
    }
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.masters-k8s-agribridge-deuces-dev.id
  }
  image_id      = "ami-052355af2a014bd2c"
  instance_type = "t3.medium"
  lifecycle {
    create_before_destroy = true
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }
  monitoring {
    enabled = false
  }
  name = "control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev"
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    ipv6_address_count          = 0
    security_groups             = [aws_security_group.masters-k8s-agribridge-deuces-dev.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      "KubernetesCluster"                                                                                     = "k8s.agribridge.deuces.dev"
      "Name"                                                                                                  = "control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                                                  = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"                               = "control-plane-us-east-1a"
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/kops-controller-pki"                         = ""
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/control-plane"                   = ""
      "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/exclude-from-external-load-balancers" = ""
      "k8s.io/role/control-plane"                                                                             = "1"
      "k8s.io/role/master"                                                                                    = "1"
      "kops.k8s.io/instancegroup"                                                                             = "control-plane-us-east-1a"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                                                       = "owned"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      "KubernetesCluster"                                                                                     = "k8s.agribridge.deuces.dev"
      "Name"                                                                                                  = "control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                                                  = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"                               = "control-plane-us-east-1a"
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/kops-controller-pki"                         = ""
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/control-plane"                   = ""
      "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/exclude-from-external-load-balancers" = ""
      "k8s.io/role/control-plane"                                                                             = "1"
      "k8s.io/role/master"                                                                                    = "1"
      "kops.k8s.io/instancegroup"                                                                             = "control-plane-us-east-1a"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                                                       = "owned"
    }
  }
  tag_specifications {
    resource_type = "network-interface"
    tags = {
      "KubernetesCluster"                                                                                     = "k8s.agribridge.deuces.dev"
      "Name"                                                                                                  = "control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                                                  = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"                               = "control-plane-us-east-1a"
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/kops-controller-pki"                         = ""
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/control-plane"                   = ""
      "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/exclude-from-external-load-balancers" = ""
      "k8s.io/role/control-plane"                                                                             = "1"
      "k8s.io/role/master"                                                                                    = "1"
      "kops.k8s.io/instancegroup"                                                                             = "control-plane-us-east-1a"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                                                       = "owned"
    }
  }
  tags = {
    "KubernetesCluster"                                                                                     = "k8s.agribridge.deuces.dev"
    "Name"                                                                                                  = "control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev"
    "aws-node-termination-handler/managed"                                                                  = ""
    "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"                               = "control-plane-us-east-1a"
    "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/kops-controller-pki"                         = ""
    "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/control-plane"                   = ""
    "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/exclude-from-external-load-balancers" = ""
    "k8s.io/role/control-plane"                                                                             = "1"
    "k8s.io/role/master"                                                                                    = "1"
    "kops.k8s.io/instancegroup"                                                                             = "control-plane-us-east-1a"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                                                       = "owned"
  }
  user_data = filebase64("${path.module}/data/aws_launch_template_control-plane-us-east-1a.masters.k8s.agribridge.deuces.dev_user_data")
}

resource "aws_launch_template" "nodes-us-east-1a-k8s-agribridge-deuces-dev" {
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      iops                  = 3000
      throughput            = 125
      volume_size           = 128
      volume_type           = "gp3"
    }
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.nodes-k8s-agribridge-deuces-dev.id
  }
  image_id      = "ami-052355af2a014bd2c"
  instance_type = "t3.medium"
  lifecycle {
    create_before_destroy = true
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }
  monitoring {
    enabled = false
  }
  name = "nodes-us-east-1a.k8s.agribridge.deuces.dev"
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    ipv6_address_count          = 0
    security_groups             = [aws_security_group.nodes-k8s-agribridge-deuces-dev.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
      "Name"                                                                       = "nodes-us-east-1a.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                       = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1a"
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
      "k8s.io/role/node"                                                           = "1"
      "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1a"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
      "Name"                                                                       = "nodes-us-east-1a.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                       = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1a"
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
      "k8s.io/role/node"                                                           = "1"
      "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1a"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
    }
  }
  tag_specifications {
    resource_type = "network-interface"
    tags = {
      "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
      "Name"                                                                       = "nodes-us-east-1a.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                       = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1a"
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
      "k8s.io/role/node"                                                           = "1"
      "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1a"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
    }
  }
  tags = {
    "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
    "Name"                                                                       = "nodes-us-east-1a.k8s.agribridge.deuces.dev"
    "aws-node-termination-handler/managed"                                       = ""
    "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1a"
    "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
    "k8s.io/role/node"                                                           = "1"
    "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1a"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
  }
  user_data = filebase64("${path.module}/data/aws_launch_template_nodes-us-east-1a.k8s.agribridge.deuces.dev_user_data")
}

resource "aws_launch_template" "nodes-us-east-1b-k8s-agribridge-deuces-dev" {
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      iops                  = 3000
      throughput            = 125
      volume_size           = 128
      volume_type           = "gp3"
    }
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.nodes-k8s-agribridge-deuces-dev.id
  }
  image_id      = "ami-052355af2a014bd2c"
  instance_type = "t3.medium"
  lifecycle {
    create_before_destroy = true
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }
  monitoring {
    enabled = false
  }
  name = "nodes-us-east-1b.k8s.agribridge.deuces.dev"
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    ipv6_address_count          = 0
    security_groups             = [aws_security_group.nodes-k8s-agribridge-deuces-dev.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
      "Name"                                                                       = "nodes-us-east-1b.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                       = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1b"
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
      "k8s.io/role/node"                                                           = "1"
      "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1b"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
      "Name"                                                                       = "nodes-us-east-1b.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                       = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1b"
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
      "k8s.io/role/node"                                                           = "1"
      "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1b"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
    }
  }
  tag_specifications {
    resource_type = "network-interface"
    tags = {
      "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
      "Name"                                                                       = "nodes-us-east-1b.k8s.agribridge.deuces.dev"
      "aws-node-termination-handler/managed"                                       = ""
      "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1b"
      "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
      "k8s.io/role/node"                                                           = "1"
      "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1b"
      "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
    }
  }
  tags = {
    "KubernetesCluster"                                                          = "k8s.agribridge.deuces.dev"
    "Name"                                                                       = "nodes-us-east-1b.k8s.agribridge.deuces.dev"
    "aws-node-termination-handler/managed"                                       = ""
    "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"    = "nodes-us-east-1b"
    "k8s.io/cluster-autoscaler/node-template/label/node-role.kubernetes.io/node" = ""
    "k8s.io/role/node"                                                           = "1"
    "kops.k8s.io/instancegroup"                                                  = "nodes-us-east-1b"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev"                            = "owned"
  }
  user_data = filebase64("${path.module}/data/aws_launch_template_nodes-us-east-1b.k8s.agribridge.deuces.dev_user_data")
}

resource "aws_route" "route-0-0-0-0--0" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.k8s-agribridge-deuces-dev.id
  route_table_id         = aws_route_table.k8s-agribridge-deuces-dev.id
}

resource "aws_route" "route-__--0" {
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.k8s-agribridge-deuces-dev.id
  route_table_id              = aws_route_table.k8s-agribridge-deuces-dev.id
}

resource "aws_route_table" "k8s-agribridge-deuces-dev" {
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "kubernetes.io/kops/role"                         = "public"
  }
  vpc_id = aws_vpc.k8s-agribridge-deuces-dev.id
}

resource "aws_route_table_association" "us-east-1a-k8s-agribridge-deuces-dev" {
  route_table_id = aws_route_table.k8s-agribridge-deuces-dev.id
  subnet_id      = aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id
}

resource "aws_route_table_association" "us-east-1b-k8s-agribridge-deuces-dev" {
  route_table_id = aws_route_table.k8s-agribridge-deuces-dev.id
  subnet_id      = aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id
}

resource "aws_s3_object" "cluster-completed-spec" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_cluster-completed.spec_content")
  key      = "k8s.agribridge.deuces.dev/cluster-completed.spec"
  provider = aws.files
}

resource "aws_s3_object" "discovery-json" {
  bucket   = "agribridge-oidc-237258628535"
  content  = file("${path.module}/data/aws_s3_object_discovery.json_content")
  key      = ".well-known/openid-configuration"
  provider = aws.files
}

resource "aws_s3_object" "etcd-cluster-spec-events" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_etcd-cluster-spec-events_content")
  key      = "k8s.agribridge.deuces.dev/backups/etcd/events/control/etcd-cluster-spec"
  provider = aws.files
}

resource "aws_s3_object" "etcd-cluster-spec-main" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_etcd-cluster-spec-main_content")
  key      = "k8s.agribridge.deuces.dev/backups/etcd/main/control/etcd-cluster-spec"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-aws-cloud-controller-addons-k8s-io-k8s-1-18" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-aws-cloud-controller.addons.k8s.io-k8s-1.18_content")
  key      = "k8s.agribridge.deuces.dev/addons/aws-cloud-controller.addons.k8s.io/k8s-1.18.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-aws-ebs-csi-driver-addons-k8s-io-k8s-1-17" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-aws-ebs-csi-driver.addons.k8s.io-k8s-1.17_content")
  key      = "k8s.agribridge.deuces.dev/addons/aws-ebs-csi-driver.addons.k8s.io/k8s-1.17.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-aws-load-balancer-controller-addons-k8s-io-k8s-1-19-irsa" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-aws-load-balancer-controller.addons.k8s.io-k8s-1.19-irsa_content")
  key      = "k8s.agribridge.deuces.dev/addons/aws-load-balancer-controller.addons.k8s.io/k8s-1.19-irsa.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-bootstrap" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-bootstrap_content")
  key      = "k8s.agribridge.deuces.dev/addons/bootstrap-channel.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-certmanager-io-k8s-1-16" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-certmanager.io-k8s-1.16_content")
  key      = "k8s.agribridge.deuces.dev/addons/certmanager.io/k8s-1.16.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-coredns-addons-k8s-io-k8s-1-12" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-coredns.addons.k8s.io-k8s-1.12_content")
  key      = "k8s.agribridge.deuces.dev/addons/coredns.addons.k8s.io/k8s-1.12.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-dns-controller-addons-k8s-io-k8s-1-12" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-dns-controller.addons.k8s.io-k8s-1.12_content")
  key      = "k8s.agribridge.deuces.dev/addons/dns-controller.addons.k8s.io/k8s-1.12.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-eks-pod-identity-webhook-addons-k8s-io-k8s-1-16" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-eks-pod-identity-webhook.addons.k8s.io-k8s-1.16_content")
  key      = "k8s.agribridge.deuces.dev/addons/eks-pod-identity-webhook.addons.k8s.io/k8s-1.16.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-kops-controller-addons-k8s-io-k8s-1-16" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-kops-controller.addons.k8s.io-k8s-1.16_content")
  key      = "k8s.agribridge.deuces.dev/addons/kops-controller.addons.k8s.io/k8s-1.16.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-kubelet-api-rbac-addons-k8s-io-k8s-1-9" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-kubelet-api.rbac.addons.k8s.io-k8s-1.9_content")
  key      = "k8s.agribridge.deuces.dev/addons/kubelet-api.rbac.addons.k8s.io/k8s-1.9.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-limit-range-addons-k8s-io" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-limit-range.addons.k8s.io_content")
  key      = "k8s.agribridge.deuces.dev/addons/limit-range.addons.k8s.io/v1.5.0.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-networking-projectcalico-org-k8s-1-25" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-networking.projectcalico.org-k8s-1.25_content")
  key      = "k8s.agribridge.deuces.dev/addons/networking.projectcalico.org/k8s-1.25.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-node-termination-handler-aws-k8s-1-11" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-node-termination-handler.aws-k8s-1.11_content")
  key      = "k8s.agribridge.deuces.dev/addons/node-termination-handler.aws/k8s-1.11.yaml"
  provider = aws.files
}

resource "aws_s3_object" "k8s-agribridge-deuces-dev-addons-storage-aws-addons-k8s-io-v1-15-0" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_k8s.agribridge.deuces.dev-addons-storage-aws.addons.k8s.io-v1.15.0_content")
  key      = "k8s.agribridge.deuces.dev/addons/storage-aws.addons.k8s.io/v1.15.0.yaml"
  provider = aws.files
}

resource "aws_s3_object" "keys-json" {
  bucket   = "agribridge-oidc-237258628535"
  content  = file("${path.module}/data/aws_s3_object_keys.json_content")
  key      = "openid/v1/jwks"
  provider = aws.files
}

resource "aws_s3_object" "kops-version-txt" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_kops-version.txt_content")
  key      = "k8s.agribridge.deuces.dev/kops-version.txt"
  provider = aws.files
}

resource "aws_s3_object" "manifests-channels-kops-channels" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_manifests-channels-kops-channels_content")
  key      = "k8s.agribridge.deuces.dev/manifests/channels/kops-channels.yaml"
  provider = aws.files
}

resource "aws_s3_object" "manifests-etcdmanager-events-control-plane-us-east-1a" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_manifests-etcdmanager-events-control-plane-us-east-1a_content")
  key      = "k8s.agribridge.deuces.dev/manifests/etcd/events-control-plane-us-east-1a.yaml"
  provider = aws.files
}

resource "aws_s3_object" "manifests-etcdmanager-main-control-plane-us-east-1a" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_manifests-etcdmanager-main-control-plane-us-east-1a_content")
  key      = "k8s.agribridge.deuces.dev/manifests/etcd/main-control-plane-us-east-1a.yaml"
  provider = aws.files
}

resource "aws_s3_object" "manifests-static-kube-apiserver-healthcheck" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_manifests-static-kube-apiserver-healthcheck_content")
  key      = "k8s.agribridge.deuces.dev/manifests/static/kube-apiserver-healthcheck.yaml"
  provider = aws.files
}

resource "aws_s3_object" "nodeupconfig-control-plane-us-east-1a" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_nodeupconfig-control-plane-us-east-1a_content")
  key      = "k8s.agribridge.deuces.dev/igconfig/control-plane/control-plane-us-east-1a/nodeupconfig.yaml"
  provider = aws.files
}

resource "aws_s3_object" "nodeupconfig-nodes-us-east-1a" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_nodeupconfig-nodes-us-east-1a_content")
  key      = "k8s.agribridge.deuces.dev/igconfig/node/nodes-us-east-1a/nodeupconfig.yaml"
  provider = aws.files
}

resource "aws_s3_object" "nodeupconfig-nodes-us-east-1b" {
  bucket   = "kops-state-607"
  content  = file("${path.module}/data/aws_s3_object_nodeupconfig-nodes-us-east-1b_content")
  key      = "k8s.agribridge.deuces.dev/igconfig/node/nodes-us-east-1b/nodeupconfig.yaml"
  provider = aws.files
}

resource "aws_security_group" "masters-k8s-agribridge-deuces-dev" {
  description = "Security group for masters"
  name        = "masters.k8s.agribridge.deuces.dev"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "masters.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
  vpc_id = aws_vpc.k8s-agribridge-deuces-dev.id
}

resource "aws_security_group" "nodes-k8s-agribridge-deuces-dev" {
  description = "Security group for nodes"
  name        = "nodes.k8s.agribridge.deuces.dev"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "nodes.k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
  vpc_id = aws_vpc.k8s-agribridge-deuces-dev.id
}

resource "aws_security_group_rule" "from-0-0-0-0--0-ingress-tcp-443to443-masters-k8s-agribridge-deuces-dev" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group_rule" "from-__--0-ingress-tcp-443to443-masters-k8s-agribridge-deuces-dev" {
  from_port         = 443
  ipv6_cidr_blocks  = ["::/0"]
  protocol          = "tcp"
  security_group_id = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group_rule" "from-masters-k8s-agribridge-deuces-dev-egress-all-0to0-0-0-0-0--0" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "from-masters-k8s-agribridge-deuces-dev-egress-all-0to0-__--0" {
  from_port         = 0
  ipv6_cidr_blocks  = ["::/0"]
  protocol          = "-1"
  security_group_id = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "from-masters-k8s-agribridge-deuces-dev-ingress-all-0to0-masters-k8s-agribridge-deuces-dev" {
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  to_port                  = 0
  type                     = "ingress"
}

resource "aws_security_group_rule" "from-masters-k8s-agribridge-deuces-dev-ingress-all-0to0-nodes-k8s-agribridge-deuces-dev" {
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  to_port                  = 0
  type                     = "ingress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-egress-all-0to0-0-0-0-0--0" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-egress-all-0to0-__--0" {
  from_port         = 0
  ipv6_cidr_blocks  = ["::/0"]
  protocol          = "-1"
  security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-ingress-4-0to0-masters-k8s-agribridge-deuces-dev" {
  from_port                = 0
  protocol                 = "4"
  security_group_id        = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-ingress-all-0to0-nodes-k8s-agribridge-deuces-dev" {
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port                  = 0
  type                     = "ingress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-1to2379-masters-k8s-agribridge-deuces-dev" {
  from_port                = 1
  protocol                 = "tcp"
  security_group_id        = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port                  = 2379
  type                     = "ingress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-2382to4000-masters-k8s-agribridge-deuces-dev" {
  from_port                = 2382
  protocol                 = "tcp"
  security_group_id        = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port                  = 4000
  type                     = "ingress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-4003to65535-masters-k8s-agribridge-deuces-dev" {
  from_port                = 4003
  protocol                 = "tcp"
  security_group_id        = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "from-nodes-k8s-agribridge-deuces-dev-ingress-udp-1to65535-masters-k8s-agribridge-deuces-dev" {
  from_port                = 1
  protocol                 = "udp"
  security_group_id        = aws_security_group.masters-k8s-agribridge-deuces-dev.id
  source_security_group_id = aws_security_group.nodes-k8s-agribridge-deuces-dev.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_sqs_queue" "k8s-agribridge-deuces-dev-nth" {
  message_retention_seconds = 300
  name                      = "k8s-agribridge-deuces-dev-nth"
  policy                    = file("${path.module}/data/aws_sqs_queue_k8s-agribridge-deuces-dev-nth_policy")
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s-agribridge-deuces-dev-nth"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_subnet" "us-east-1a-k8s-agribridge-deuces-dev" {
  availability_zone                           = "us-east-1a"
  cidr_block                                  = "172.20.0.0/17"
  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "resource-name"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "us-east-1a.k8s.agribridge.deuces.dev"
    "SubnetType"                                      = "Public"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/role/internal-elb"                 = "1"
  }
  vpc_id = aws_vpc.k8s-agribridge-deuces-dev.id
}

resource "aws_subnet" "us-east-1b-k8s-agribridge-deuces-dev" {
  availability_zone                           = "us-east-1b"
  cidr_block                                  = "172.20.128.0/17"
  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "resource-name"
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "us-east-1b.k8s.agribridge.deuces.dev"
    "SubnetType"                                      = "Public"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/role/internal-elb"                 = "1"
  }
  vpc_id = aws_vpc.k8s-agribridge-deuces-dev.id
}

resource "aws_vpc" "k8s-agribridge-deuces-dev" {
  assign_generated_ipv6_cidr_block = true
  cidr_block                       = "172.20.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_vpc_dhcp_options" "k8s-agribridge-deuces-dev" {
  domain_name         = "ec2.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
  tags = {
    "KubernetesCluster"                               = "k8s.agribridge.deuces.dev"
    "Name"                                            = "k8s.agribridge.deuces.dev"
    "kubernetes.io/cluster/k8s.agribridge.deuces.dev" = "owned"
  }
}

resource "aws_vpc_dhcp_options_association" "k8s-agribridge-deuces-dev" {
  dhcp_options_id = aws_vpc_dhcp_options.k8s-agribridge-deuces-dev.id
  vpc_id          = aws_vpc.k8s-agribridge-deuces-dev.id
}

terraform {
  required_version = ">= 0.15.0"
  required_providers {
    aws = {
      "configuration_aliases" = [aws.files]
      "source"                = "hashicorp/aws"
      "version"               = ">= 5.0.0"
    }
  }
}
