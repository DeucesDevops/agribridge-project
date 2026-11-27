resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name        = local.storage_class.metadata.name
    annotations = try(local.storage_class.metadata.annotations, {})
  }

  storage_provisioner    = local.storage_class.provisioner
  reclaim_policy         = local.storage_class.reclaimPolicy
  volume_binding_mode    = local.storage_class.volumeBindingMode
  allow_volume_expansion = local.storage_class.allowVolumeExpansion
  parameters             = local.storage_class.parameters
}
