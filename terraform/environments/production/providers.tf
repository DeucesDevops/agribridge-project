provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "agribridge"
      ManagedBy = "terraform"
    }
  }
}

# kOps uses this alias for the objects it writes into the state and discovery buckets.
provider "aws" {
  alias  = "files"
  region = var.region
}

# GITHUB_TOKEN is read from the environment. It is the credential Terraform
# uses to publish Actions variables. It is not a copy of an output.
provider "github" {
  owner = local.github_owner
}

# These providers are configured for every plan. Terraform reads the kubeconfig
# only when install_platform is true and the platform module is created.
# `kops export kubeconfig --admin` writes that file. The admin credential lives
# in the kOps state bucket, which the deploy role can read.
provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}

provider "helm" {
  kubernetes {
    config_path = pathexpand(var.kubeconfig_path)
  }
}
