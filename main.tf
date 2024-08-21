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

# resource "null_resource" "kops_cluster" {
#   provisioner "local-exec" {
#     command = <<EOT
#       kops create cluster \
#         --name=mycluster.k8s.local \
#         --state=s3://my-kops-state-store \
#         --zones=us-west-2a,us-west-2b \
#         --node-count=2 \
#         --node-size=t3.medium \
#         --master-size=t3.medium \
#         --vpc=${aws_vpc.main_vpc.id} \
#         --subnets=${aws_subnet.private_subnet_1.id},${aws_subnet.private_subnet_2.id} \
#         --out=kops-terraform/
      
#       kops update cluster --name=mycluster.k8s.local --yes
#       kops export kubecfg --name=mycluster.k8s.local
#     EOT
#   }

#   triggers = {
#     cluster_update = "${timestamp()}"
#   }

#   depends_on = [aws_vpc.main_vpc]
# }

# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config"
#   }
# }

# resource "helm_release" "nginx_ingress" {
#   count = var.use_ingress_controller ? 1 : 0

#   name       = "nginx-ingress"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   namespace  = "kube-system"

#   values = [
#     file("values.yaml")
#   ]
# }

# resource "helm_release" "frontend_app" {
#   name       = "frontend-app"
#   repository = "https://example.com/charts"
#   chart      = "frontend-app"
#   namespace  = "default"

#   values = [
#     file("frontend-values.yaml")
#   ]
# }

# resource "helm_release" "backend_app" {
#   name       = "backend-app"
#   repository = "https://example.com/charts"
#   chart      = "backend-app"
#   namespace  = "default"

#   values = [
#     file("backend-values.yaml")
#   ]
# }

# resource "helm_release" "nginx_ingress" {
#   name       = "nginx-ingress"
#   repository = "https://kubernetes.github.io/ingress-nginx/"
#   chart      = "ingress-nginx"
#   namespace  = "ingress-nginx"

#   set {
#     name  = "controller.service.type"
#     value = "LoadBalancer"
#   }
# }

# resource "aws_iam_role" "alb_ingress_controller" {
#   name = "alb-ingress-controller"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "alb_ingress_controller_attach" {
#   role       = aws_iam_role.alb_ingress_controller.name
#   policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
# }

# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config"
#   }
# }

# resource "helm_release" "alb_ingress" {
#   name       = "aws-load-balancer-controller"
#   chart      = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   namespace  = "kube-system"

#   set {
#     name  = "clusterName"
#     value = "my-cluster"
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = "false"
#   }
# }

# resource "kubernetes_service" "my_service" {
#   metadata {
#     name      = "my-service"
#     namespace = "default"
#     annotations = {
#       "service.beta.kubernetes.io/aws-load-balancer-internal" = "0.0.0.0/0"
#     }
#   }
#   spec {
#     selector = {
#       app = "my-app"
#     }
#     port {
#       port        = 80
#       target_port = 8080
#     }
#     type = "LoadBalancer"
#   }
# }

# provider "aws" {
#   region = "us-east-1"  # Replace with your AWS region
# }

# provider "kubernetes" {
#   host                   = "https://<KUBERNETES_API_SERVER>"
#   token                  = "<KUBERNETES_TOKEN>"
#   cluster_ca_certificate = file("<PATH_TO_CA_CERT>")
# }

# Replace <KUBERNETES_API_SERVER>, <KUBERNETES_TOKEN>, and <PATH_TO_CA_CERT> with the actual values from your kOps cluster. You can get these values from the kubeconfig file that kOps generates.

# provider "helm" {
#   kubernetes {
#     host                   = "https://<KUBERNETES_API_SERVER>"
#     token                  = "<KUBERNETES_TOKEN>"
#     cluster_ca_certificate = file("<PATH_TO_CA_CERT>")
#   }
# }

# resource "helm_release" "nginx_ingress" {
#   name       = "nginx-ingress"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   namespace  = "default"
  
#   set {
#     name  = "controller.service.type"
#     value = "LoadBalancer"
#   }
# }