# The image name is the one in kops/cluster.yaml. Looking it up here means a
# refreshed kOps render does not have to bake in an AMI id from the account
# that happened to generate the files.
data "aws_ami" "kops_node" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20260714"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
