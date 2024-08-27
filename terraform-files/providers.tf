terraform {
  required_providers {
    aws        = {
      source   = "hashicorp/aws"
      version  = "5.64.0"
    }
    kubernetes = {
      source   = "hashicorp/kubernetes"
      version  = "2.32.0"
    }
    helm       = {
      source   = "hashicorp/helm"
      version  = "2.15.0"
    }
  }
}

provider "aws" {
  alias  = "aws-region-provider"
  region = var.aws_region
}

provider "kubernetes" {
  config_path = var.config_path
}

provider "helm" {
  kubernetes {
    config_path = var.config_path
  }
}