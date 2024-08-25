variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type = string
}

variable "az_count" {
  description = "The number of availability zones to use (1-5)"
  type = number
}

variable "public_subnet_cidr_blocks" {
  description = "The CIDR blocks for the public subnets"
  type = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "The CIDR blocks for the private subnets"
  type = list(string)
}

variable "azs" {
  description = "The availability zones to use"
  type = list(string)
}

variable "tags" {
  description = "The tags to apply to the resources"
  type = map(string)
}

variable "vpc_name" {
  description = "The name of the VPC"
  type = string
}

variable "kops_cluster_name" {
  description = "The name of the Kops cluster"
  type = string
}