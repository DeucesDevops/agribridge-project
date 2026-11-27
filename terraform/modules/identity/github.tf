data "github_user" "reviewer" {
  for_each = var.manage_github ? toset(["production"]) : toset([])

  username = var.github_reviewer
}

resource "github_actions_variable" "this" {
  for_each = var.manage_github ? local.github_variable_names : toset([])

  repository    = local.github_name
  variable_name = each.key
  value         = local.github_variable_values[each.value]
}

resource "github_repository_environment" "production" {
  for_each = var.manage_github ? toset(["production"]) : toset([])

  repository          = local.github_name
  environment         = "production"
  prevent_self_review = false

  reviewers {
    users = [data.github_user.reviewer[each.key].id]
  }
}
