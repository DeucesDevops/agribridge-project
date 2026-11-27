variable "vpc_id" {
  description = "VPC id from the network module. Control-plane and node resources are created in this VPC."
  type        = string
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR of the VPC."
  type        = string
}

variable "vpc_ipv6_cidr_block" {
  description = "IPv6 CIDR assigned to the VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet ids keyed by availability zone. kOps places nodes here. There is no NAT gateway."
  type        = map(string)
}

variable "public_route_table_id" {
  description = "Public route table. Its default routes send 0.0.0.0/0 and ::/0 to the internet gateway."
  type        = string
}
