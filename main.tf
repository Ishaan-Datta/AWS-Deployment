terraform {
  required_providers { # add required providers here
    aws = {
      version = "4.67.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# Configure AWS provider
provider "aws" {
  alias = "us-east-1"
  region = "us-east-1" # Update with your desired region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# K8s Provider Configuration: allows Terraform to interact with your Kubernetes cluster and manage Kubernetes resources
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.auth.token
}

# Helm Provider Configuration: allows Terraform to manage Helm charts
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.auth.token
    # config_path = "~/.kube/config"
  }
}

resource "aws_s3_bucket" "kops_bucket" {
  provider = aws.us-east-1
  bucket   = "AWS-test-kops-bucket" # variable later
}

resource "aws_s3_bucket_public_access_block" "example" {
  provider = aws.us-east-1
  bucket   = aws_s3_bucket.kops_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "example" {
  provider = aws.us-east-1
  bucket   = aws_s3_bucket.kops_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  provider = aws.us-east-1
  depends_on = [
    aws_s3_bucket_public_access_block.example,
    aws_s3_bucket_ownership_controls.example,
  ]

  bucket = aws_s3_bucket.kops_bucket.id
  acl    = "public-read"
}

# IAM Role for Kops cluster management
resource "aws_iam_role" "kops_role" {
  name = "kops-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
  ]
}

# Helm chart deployment
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx/"
  chart      = "ingress-nginx"
  version    = "4.0.19"
  namespace  = "ingress-nginx"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.config.name"
    value = "custom-nginx-config"
  }

  # set {
  #   name  = "ingress.enabled"
  #   value = "true"
  # }

  set {
    name  = "env.DB_USERNAME"
    value = random_password.db_username.result
  }

  set {
    name  = "env.DB_PASSWORD"
    value = random_password.db_password.result
  }

  set {
    name  = "env.DB_URL"
    value = aws_db_instance.example.endpoint
  }
}

resource "helm_release" "helm_deployment" {
  name       = "helm_deployment"
  repository = "https://example.com/charts"
  chart      = "backend-app"
  namespace  = "default"

  values = [
    file("backend-values.yaml")
  ]
}