output "repositories" {
  value = {
    api = "docker.io/${var.dockerhub_username}/agribridge-api"
    web = "docker.io/${var.dockerhub_username}/agribridge-web"
  }
}
# Existing ECR repositories remain managed to avoid deleting prior resources.
output "legacy_ecr_repositories" { value = { for k, r in aws_ecr_repository.app : k => r.repository_url } }
