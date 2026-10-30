module "cluster" {
  source = "../modules/kops-cluster"
  providers = {
    aws       = aws
    aws.files = aws.files
  }
}
