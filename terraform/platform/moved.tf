moved {
  from = kubernetes_namespace_v1.app
  to   = module.platform.kubernetes_namespace_v1.app
}

moved {
  from = helm_release.secrets
  to   = module.platform.helm_release.secrets
}

moved {
  from = helm_release.ingress
  to   = module.platform.helm_release.ingress
}

moved {
  from = aws_route53_record.app
  to   = module.platform.aws_route53_record.app
}

moved {
  from = helm_release.monitoring
  to   = module.platform.helm_release.monitoring
}

moved {
  from = kubernetes_service_account_v1.pipeline
  to   = module.platform.kubernetes_service_account_v1.pipeline
}

moved {
  from = kubernetes_role_v1.pipeline
  to   = module.platform.kubernetes_role_v1.pipeline
}

moved {
  from = kubernetes_role_binding_v1.pipeline
  to   = module.platform.kubernetes_role_binding_v1.pipeline
}

moved {
  from = kubernetes_secret_v1.pipeline
  to   = module.platform.kubernetes_secret_v1.pipeline
}

moved {
  from = aws_secretsmanager_secret.pipeline
  to   = module.platform.aws_secretsmanager_secret.pipeline
}

moved {
  from = aws_secretsmanager_secret_version.pipeline
  to   = module.platform.aws_secretsmanager_secret_version.pipeline
}

moved {
  from = kubernetes_storage_class_v1.gp3
  to   = module.platform.kubernetes_storage_class_v1.gp3
}

moved {
  from = helm_release.logs
  to   = module.platform.helm_release.logs
}
