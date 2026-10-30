resource "aws_ecr_repository" "app" {
  for_each             = toset(["api", "web"])
  name                 = "agribridge-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
