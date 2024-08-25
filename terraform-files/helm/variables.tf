variable "use_ingress_controller" {
  description = "Toggle to use Ingress Controller (true) or Direct Load Balancer (false)"
  type        = bool
}

variable "namespace" {
  description = "The namespace to deploy the Helm chart to"
  type        = string
}

variable "deployment_name" {
  description = "The name of the deployment"
  type        = string
}

variable "az_count" {
  description = "The number of availability zones to use (1-5)"
  type        = number
}

variable "aws_region" {
  description = "The AWS region in which to deploy the resources"
  type        = string
}

variable "helm_chart_path" {
  description = "The path to the Helm chart to deploy"
  type        = string
}