variable "vpc_id" {
  description = "The VPC ID where the resources will be created"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 Key pair name"
  type        = string
}

variable "allowed_ips" {
  description = "Allowed IPs to access RDS"
  type        = list(string)
}

# take input argument variable that will set the argument within the helm deployment
variable "use_ingress_controller" {
  description = "Toggle to use Ingress Controller (true) or Direct Load Balancer (false)"
  type        = bool
  default     = true
}