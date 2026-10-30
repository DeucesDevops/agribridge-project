# Flat Kubernetes definitions

Keep the editable kOps cluster and instance-group YAML directly in this folder.
`cluster.yaml` contains all four objects in one file. Generated AWS Terraform belongs in `terraform/modules/kops-cluster`, called by `terraform/cluster`, outside this folder.

The application is delivered by the single chart in `helm/agribridge`, as required by the assessment. To inspect its plain Kubernetes definitions in this same flat folder, run:

```sh
bash scripts/render-manifests.sh staging IMAGE_TAG
```

This writes `kops/staging-rendered.yaml` with all application objects, including its Namespace. It contains secret identifiers and references, never secret values. Do not apply the render alongside a Helm release; deploy with `scripts/deploy.sh` so Helm owns release history and rollback. Renders are ignored by Git because they are generated for a particular release.
