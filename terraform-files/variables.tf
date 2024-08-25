variable "aws_region" {
  description     = "The AWS region in which to deploy the resources"
  type            = string
  default         = "ca-central-1"
  validation {
    condition     = contains(data.aws_regions.available.names, var.aws_region)
    error_message = "Invalid AWS region. Please provide a valid AWS region from the available regions."
  }
}

variable "az_count" {
  description     = "The number of availability zones to use (1-5)"
  type            = number
  default         = 3
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 5
    error_message = "The number of AZs must be between 1 and 5."
  }
}

variable "use_ingress_controller" {
  description = "Toggle to use Ingress Controller (true) or Direct Load Balancer (false)"
  type        = bool
  default     = false
}

variable "environment_name" {
  description = "The name of the Terraform environment to create resources under"
  type        = string
  default     = "dev"
}

variable "namespace" {
  description = "The namespace to deploy the Helm chart to"
  type        = string
  default     = "AWS-Deployment"
}

variable "deployment_name" {
  description = "The name of the deployment"
  type        = string
  default     = "AWS-Deployment"
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "vpc-dev"
}

variable "ssh_key_path" {
  description = "The path to the SSH public key to be used for the bastion hosts"
  type        = string
  default     = pathexpand("~/.ssh/id_rsa.pub")
}

variable "config_path" {
  description = "The path to the kubeconfig file"
  type        = string
  default     = pathexpand("~/.kube/config")
}