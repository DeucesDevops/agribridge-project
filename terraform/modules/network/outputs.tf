output "vpc_id" {
  description = "VPC created for the kOps cluster."
  value       = aws_vpc.k8s-agribridge-deuces-dev.id
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR of the VPC."
  value       = aws_vpc.k8s-agribridge-deuces-dev.cidr_block
}

output "vpc_ipv6_cidr_block" {
  description = "IPv6 CIDR AWS assigns to the VPC."
  value       = aws_vpc.k8s-agribridge-deuces-dev.ipv6_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet ids keyed by availability zone. Nodes use these subnets directly. There is no NAT gateway."
  value = {
    "us-east-1a" = aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id
    "us-east-1b" = aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id
  }
}

output "node_subnet_ids" {
  description = "Public subnet ids in availability-zone order."
  value       = [aws_subnet.us-east-1a-k8s-agribridge-deuces-dev.id, aws_subnet.us-east-1b-k8s-agribridge-deuces-dev.id]
}

output "public_route_table_id" {
  description = "Route table whose default routes send traffic to the internet gateway."
  value       = aws_route_table.k8s-agribridge-deuces-dev.id
}
