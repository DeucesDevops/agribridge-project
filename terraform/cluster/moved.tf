moved {
  from = aws_autoscaling_group.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_autoscaling_group.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_autoscaling_group.nodes-us-east-1a-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_autoscaling_group.nodes-us-east-1a-k8s-agribridge-deuces-dev
}

moved {
  from = aws_autoscaling_group.nodes-us-east-1b-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_autoscaling_group.nodes-us-east-1b-k8s-agribridge-deuces-dev
}

moved {
  from = aws_autoscaling_lifecycle_hook.control-plane-us-east-1a-NTHLifecycleHook
  to   = module.cluster.aws_autoscaling_lifecycle_hook.control-plane-us-east-1a-NTHLifecycleHook
}

moved {
  from = aws_autoscaling_lifecycle_hook.nodes-us-east-1a-NTHLifecycleHook
  to   = module.cluster.aws_autoscaling_lifecycle_hook.nodes-us-east-1a-NTHLifecycleHook
}

moved {
  from = aws_autoscaling_lifecycle_hook.nodes-us-east-1b-NTHLifecycleHook
  to   = module.cluster.aws_autoscaling_lifecycle_hook.nodes-us-east-1b-NTHLifecycleHook
}

moved {
  from = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-ASGLifecycle
  to   = module.cluster.aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-ASGLifecycle
}

moved {
  from = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-InstanceScheduledChange
  to   = module.cluster.aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-InstanceScheduledChange
}

moved {
  from = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-InstanceStateChange
  to   = module.cluster.aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-InstanceStateChange
}

moved {
  from = aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-SpotInterruption
  to   = module.cluster.aws_cloudwatch_event_rule.k8s-agribridge-deuces-dev-SpotInterruption
}

moved {
  from = aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-ASGLifecycle-Target
  to   = module.cluster.aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-ASGLifecycle-Target
}

moved {
  from = aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-InstanceScheduledChange-Target
  to   = module.cluster.aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-InstanceScheduledChange-Target
}

moved {
  from = aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-InstanceStateChange-Target
  to   = module.cluster.aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-InstanceStateChange-Target
}

moved {
  from = aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-SpotInterruption-Target
  to   = module.cluster.aws_cloudwatch_event_target.k8s-agribridge-deuces-dev-SpotInterruption-Target
}

moved {
  from = aws_ebs_volume.a-etcd-events-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_ebs_volume.a-etcd-events-k8s-agribridge-deuces-dev
}

moved {
  from = aws_ebs_volume.a-etcd-main-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_ebs_volume.a-etcd-main-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_instance_profile.masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_instance_profile.masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_instance_profile.nodes-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_instance_profile.nodes-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_openid_connect_provider.k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_openid_connect_provider.k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp
  to   = module.cluster.aws_iam_role.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp
}

moved {
  from = aws_iam_role.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3
  to   = module.cluster.aws_iam_role.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3
}

moved {
  from = aws_iam_role.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf
  to   = module.cluster.aws_iam_role.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf
}

moved {
  from = aws_iam_role.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role.masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role.masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role.nodes-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role.nodes-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role_policy.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp
  to   = module.cluster.aws_iam_role_policy.aws-cloud-controller-manager-kube-system-sa-k8s-agribridg-em0qfp
}

moved {
  from = aws_iam_role_policy.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3
  to   = module.cluster.aws_iam_role_policy.aws-load-balancer-controller-kube-system-sa-k8s-agribridg-5s6ug3
}

moved {
  from = aws_iam_role_policy.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf
  to   = module.cluster.aws_iam_role_policy.aws-node-termination-handler-kube-system-sa-k8s-agribridg-5ejarf
}

moved {
  from = aws_iam_role_policy.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role_policy.dns-controller-kube-system-sa-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role_policy.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role_policy.ebs-csi-controller-sa-kube-system-sa-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role_policy.masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role_policy.masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_iam_role_policy.nodes-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_iam_role_policy.nodes-k8s-agribridge-deuces-dev
}

moved {
  from = aws_internet_gateway.k8s-agribridge-deuces-dev
  to   = module.cluster.aws_internet_gateway.k8s-agribridge-deuces-dev
}

moved {
  from = aws_launch_template.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_launch_template.control-plane-us-east-1a-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_launch_template.nodes-us-east-1a-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_launch_template.nodes-us-east-1a-k8s-agribridge-deuces-dev
}

moved {
  from = aws_launch_template.nodes-us-east-1b-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_launch_template.nodes-us-east-1b-k8s-agribridge-deuces-dev
}

moved {
  from = aws_route.route-0-0-0-0--0
  to   = module.cluster.aws_route.route-0-0-0-0--0
}

moved {
  from = aws_route.route-__--0
  to   = module.cluster.aws_route.route-__--0
}

moved {
  from = aws_route_table.k8s-agribridge-deuces-dev
  to   = module.cluster.aws_route_table.k8s-agribridge-deuces-dev
}

moved {
  from = aws_route_table_association.us-east-1a-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_route_table_association.us-east-1a-k8s-agribridge-deuces-dev
}

moved {
  from = aws_route_table_association.us-east-1b-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_route_table_association.us-east-1b-k8s-agribridge-deuces-dev
}

moved {
  from = aws_s3_object.cluster-completed-spec
  to   = module.cluster.aws_s3_object.cluster-completed-spec
}

moved {
  from = aws_s3_object.discovery-json
  to   = module.cluster.aws_s3_object.discovery-json
}

moved {
  from = aws_s3_object.etcd-cluster-spec-events
  to   = module.cluster.aws_s3_object.etcd-cluster-spec-events
}

moved {
  from = aws_s3_object.etcd-cluster-spec-main
  to   = module.cluster.aws_s3_object.etcd-cluster-spec-main
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-aws-cloud-controller-addons-k8s-io-k8s-1-18
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-aws-cloud-controller-addons-k8s-io-k8s-1-18
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-aws-ebs-csi-driver-addons-k8s-io-k8s-1-17
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-aws-ebs-csi-driver-addons-k8s-io-k8s-1-17
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-aws-load-balancer-controller-addons-k8s-io-k8s-1-19-irsa
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-aws-load-balancer-controller-addons-k8s-io-k8s-1-19-irsa
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-bootstrap
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-bootstrap
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-certmanager-io-k8s-1-16
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-certmanager-io-k8s-1-16
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-coredns-addons-k8s-io-k8s-1-12
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-coredns-addons-k8s-io-k8s-1-12
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-dns-controller-addons-k8s-io-k8s-1-12
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-dns-controller-addons-k8s-io-k8s-1-12
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-eks-pod-identity-webhook-addons-k8s-io-k8s-1-16
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-eks-pod-identity-webhook-addons-k8s-io-k8s-1-16
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-kops-controller-addons-k8s-io-k8s-1-16
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-kops-controller-addons-k8s-io-k8s-1-16
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-kubelet-api-rbac-addons-k8s-io-k8s-1-9
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-kubelet-api-rbac-addons-k8s-io-k8s-1-9
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-limit-range-addons-k8s-io
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-limit-range-addons-k8s-io
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-networking-projectcalico-org-k8s-1-25
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-networking-projectcalico-org-k8s-1-25
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-node-termination-handler-aws-k8s-1-11
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-node-termination-handler-aws-k8s-1-11
}

moved {
  from = aws_s3_object.k8s-agribridge-deuces-dev-addons-storage-aws-addons-k8s-io-v1-15-0
  to   = module.cluster.aws_s3_object.k8s-agribridge-deuces-dev-addons-storage-aws-addons-k8s-io-v1-15-0
}

moved {
  from = aws_s3_object.keys-json
  to   = module.cluster.aws_s3_object.keys-json
}

moved {
  from = aws_s3_object.kops-version-txt
  to   = module.cluster.aws_s3_object.kops-version-txt
}

moved {
  from = aws_s3_object.manifests-channels-kops-channels
  to   = module.cluster.aws_s3_object.manifests-channels-kops-channels
}

moved {
  from = aws_s3_object.manifests-etcdmanager-events-control-plane-us-east-1a
  to   = module.cluster.aws_s3_object.manifests-etcdmanager-events-control-plane-us-east-1a
}

moved {
  from = aws_s3_object.manifests-etcdmanager-main-control-plane-us-east-1a
  to   = module.cluster.aws_s3_object.manifests-etcdmanager-main-control-plane-us-east-1a
}

moved {
  from = aws_s3_object.manifests-static-kube-apiserver-healthcheck
  to   = module.cluster.aws_s3_object.manifests-static-kube-apiserver-healthcheck
}

moved {
  from = aws_s3_object.nodeupconfig-control-plane-us-east-1a
  to   = module.cluster.aws_s3_object.nodeupconfig-control-plane-us-east-1a
}

moved {
  from = aws_s3_object.nodeupconfig-nodes-us-east-1a
  to   = module.cluster.aws_s3_object.nodeupconfig-nodes-us-east-1a
}

moved {
  from = aws_s3_object.nodeupconfig-nodes-us-east-1b
  to   = module.cluster.aws_s3_object.nodeupconfig-nodes-us-east-1b
}

moved {
  from = aws_security_group.masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group.masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group.nodes-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group.nodes-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-0-0-0-0--0-ingress-tcp-443to443-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-0-0-0-0--0-ingress-tcp-443to443-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-__--0-ingress-tcp-443to443-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-__--0-ingress-tcp-443to443-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-egress-all-0to0-0-0-0-0--0
  to   = module.cluster.aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-egress-all-0to0-0-0-0-0--0
}

moved {
  from = aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-egress-all-0to0-__--0
  to   = module.cluster.aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-egress-all-0to0-__--0
}

moved {
  from = aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-ingress-all-0to0-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-ingress-all-0to0-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-ingress-all-0to0-nodes-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-masters-k8s-agribridge-deuces-dev-ingress-all-0to0-nodes-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-egress-all-0to0-0-0-0-0--0
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-egress-all-0to0-0-0-0-0--0
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-egress-all-0to0-__--0
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-egress-all-0to0-__--0
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-4-0to0-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-4-0to0-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-all-0to0-nodes-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-all-0to0-nodes-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-1to2379-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-1to2379-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-2382to4000-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-2382to4000-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-4003to65535-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-tcp-4003to65535-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-udp-1to65535-masters-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_security_group_rule.from-nodes-k8s-agribridge-deuces-dev-ingress-udp-1to65535-masters-k8s-agribridge-deuces-dev
}

moved {
  from = aws_sqs_queue.k8s-agribridge-deuces-dev-nth
  to   = module.cluster.aws_sqs_queue.k8s-agribridge-deuces-dev-nth
}

moved {
  from = aws_subnet.us-east-1a-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_subnet.us-east-1a-k8s-agribridge-deuces-dev
}

moved {
  from = aws_subnet.us-east-1b-k8s-agribridge-deuces-dev
  to   = module.cluster.aws_subnet.us-east-1b-k8s-agribridge-deuces-dev
}

moved {
  from = aws_vpc.k8s-agribridge-deuces-dev
  to   = module.cluster.aws_vpc.k8s-agribridge-deuces-dev
}

moved {
  from = aws_vpc_dhcp_options.k8s-agribridge-deuces-dev
  to   = module.cluster.aws_vpc_dhcp_options.k8s-agribridge-deuces-dev
}

moved {
  from = aws_vpc_dhcp_options_association.k8s-agribridge-deuces-dev
  to   = module.cluster.aws_vpc_dhcp_options_association.k8s-agribridge-deuces-dev
}
