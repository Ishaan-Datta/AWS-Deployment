variable "cluster_name" {
  description = "The name of the Kops cluster"
  type        = string
}

variable "state_store" {
    description = "The name of the S3 bucket to store the Kops state"
    type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "The IDs of the public subnets"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "The IDs of the private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "The availability zones"
  type        = list(string)
}

variable "ssh_key_path" {
  description = "The path to the SSH key"
  type        = string
}

variable "tags" {
  description = "The tags to apply to the resources"
  type        = map(string)
}

variable "enable_bastion" {
  description = "Whether to enable the bastion host"
  type        = bool
}