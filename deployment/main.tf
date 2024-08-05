# Configure AWS provider
provider "aws" {
  region = "us-east-1" # Update with your desired region
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.auth.token
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.auth.token
  }
}

# Create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnets
resource "aws_subnet" "private_subnet" {
  count = 2
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, count.index)
}

# Create Security Group
resource "aws_security_group" "eks_security_group" {
  vpc_id = aws_vpc.main_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create IAM Role and Policy for EKS
resource "aws_iam_role" "eks_role" {
  name = "eks_role"
  
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "eks_policy_attachment" {
  name       = "eks_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  roles      = [aws_iam_role.eks_role.name]
}

# Create EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.private_subnet.*.id
    security_group_ids = [aws_security_group.eks_security_group.id]
  }
}

# Output EKS Cluster Endpoint and ARN
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_arn" {
  value = aws_eks_cluster.eks_cluster.arn
}

# S3 Bucket for uploaded CSV files
resource "aws_s3_bucket" "csv_files_bucket" {
  bucket = "csv-files-bucket" # Update with your desired bucket name
}

# S3 Bucket for Kubeflow pipeline artifacts and data
resource "aws_s3_bucket" "kubeflow_bucket" {
  bucket = "kubeflow-bucket" # Update with your desired bucket name
}

# Route 53 DNS Zone
resource "aws_route53_zone" "main_dns_zone" {
  name = "example.com" # Update with your desired domain name
}

# Create Route 53 DNS Record
resource "aws_route53_record" "kubeflow_pipeline" {
  zone_id = aws_route53_zone.main_dns_zone.zone_id
  name    = "pipeline.example.com"
  type    = "CNAME"
  ttl     = 300
  records = [module.alb.dns_name]
}

# ALB Ingress Controller
module "alb_ingress_controller" {
  source = "terraform-aws-modules/eks/aws//modules/alb-ingress-controller"

  cluster_name       = aws_eks_cluster.eks_cluster.id
  cluster_endpoint   = aws_eks_cluster.eks_cluster.endpoint
  vpc_id             = aws_vpc.main_vpc.id
  region             = "us-east-1" # Update with your desired region
  oidc_provider_arn  = aws_iam_openid_connect_provider.eks.arn
  aws_load_balancer_controller_version = "v2.2.3" # Update to the latest version
}

# Deploy the Helm chart using Terraform
resource "helm_release" "kubeflow_pipeline" {
  name       = "kubeflow-pipeline"
  repository = "https://example.com/charts" # Update with your chart repository
  chart      = "kubeflow-pipeline"
  namespace  = "kubeflow"

  set {
    name  = "image.repository"
    value = "your-docker-repo/kubeflow-pipeline"
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.hosts[0].host"
    value = "pipeline.example.com"
  }

  set {
    name  = "ingress.hosts[0].paths[0]"
    value = "/"
  }
}

# NEW ONE

# terraform {
#   required_providers {
#     aws = {
#       version = "4.67.0"
#     }
#   }
# }

# provider "aws" {
#   alias = "us-east-1"

#   region = "us-east-1"
# }

# data "aws_availability_zones" "available" {
#   state = "available"
# }

# resource "random_string" "random" {
#   length  = 16
#   lower   = true
#   upper   = false
#   special = false
#   numeric = false
# }

# resource "aws_s3_bucket" "kops_bucket" {
#   provider = aws.us-east-1
#   bucket   = "${random_string.random.result}-kops-bucket"
# }

# resource "aws_s3_bucket_public_access_block" "example" {
#   provider = aws.us-east-1
#   bucket   = aws_s3_bucket.kops_bucket.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_ownership_controls" "example" {
#   provider = aws.us-east-1
#   bucket   = aws_s3_bucket.kops_bucket.id
#   rule {
#     object_ownership = "BucketOwnerPreferred"
#   }
# }

# resource "aws_s3_bucket_acl" "example" {
#   provider = aws.us-east-1
#   depends_on = [
#     aws_s3_bucket_public_access_block.example,
#     aws_s3_bucket_ownership_controls.example,
#   ]

#   bucket = aws_s3_bucket.kops_bucket.id
#   acl    = "public-read"
# }

# output "s3_bucket" {
#   value = aws_s3_bucket.kops_bucket.id
# }

# output "az" {
#   value = data.aws_availability_zones.available.names[0]
# }

# // We're storing the cluster name in our Terraform state so that
# // we don't have to use our shell's environment to remember it.
# output "cluster_name" {
#   value = "kops-cluster-${random_string.random.result}.k8s.local"
# }



#### NEW
# terraform {
#   required_providers {
#     aws = {
#       version = "4.67.0"
#     }
#   }
#   backend "s3" {}
# }

# variable "my_ip_address" {
#   description = "Your external IP address (i.e. not your NAT'ed one, like 192.168.x.x"
# }


# data "aws_availability_zones" "available" {
#   state = "available"
# }

# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["099720109477"] # Canonical
# }

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "4.0.2"

#   name               = "kubernetes-iac-vpc"
#   cidr               = "172.17.0.0/16"
#   azs                = [data.aws_availability_zones.available.names[0]]
#   private_subnets    = ["172.17.1.0/24"]
#   public_subnets     = ["172.17.100.0/24"]
#   enable_nat_gateway = "true"
# }

# module "sg" {
#   source  = "terraform-aws-modules/security-group/aws//modules/ssh"
#   version = "4.17.2"
#   name    = "kubernetes-iac-sg"
#   vpc_id  = module.vpc.vpc_id

#   ingress_cidr_blocks = ["${var.my_ip_address}/32"]
# }

# module "keypair" {
#   source             = "terraform-aws-modules/key-pair/aws"
#   version            = "2.0.2"
#   key_name           = "kubernetes-iac-key"
#   create_private_key = true
# }

# module "ec2_instance" {
#   source                      = "terraform-aws-modules/ec2-instance/aws"
#   version                     = "5.0.0"
#   count                       = 2
#   name                        = "kubernetes-iac-instance-${count.index}"
#   instance_type               = "t2.2xlarge"
#   ami                         = data.aws_ami.ubuntu.id
#   key_name                    = module.keypair.key_pair_name
#   vpc_security_group_ids      = [module.sg.security_group_id]
#   subnet_id                   = module.vpc.public_subnets[0]
#   associate_public_ip_address = true
#   create_iam_instance_profile = true
#   // Comment the line below to disable spot pricing.
#   // 
#   // AWS EC2 Spot helps you save money by using unused compute at super
#   // deep discounts.
#   //
#   // Instances provisioned by Spot are the same as
#   // regular instances with a caveat that they get shut down if the
#   // instance type's regular price exceeds your spot price.
#   spot_price = "0.18"
# }

# output "private_key" {
#   value     = module.keypair.private_key_openssh
#   sensitive = true
# }

# output "node_a_ip_address" {
#   value = module.ec2_instance.0.public_ip
# }

# output "node_b_ip_address" {
#   value = module.ec2_instance.1.public_ip
# }

# output "node_a_internal_ip_address" {
#   value = module.ec2_instance.0.private_ip
# }

# output "node_b_internal_ip_address" {
#   value = module.ec2_instance.1.private_ip
# }

# cluster.tf:
# terraform {
#   backend "s3" {}
# }

# data "aws_eks_cluster" "cluster" {
#   name = module.explore-california-cluster.cluster_id
# }

# data "aws_eks_cluster_auth" "cluster" {
#   name = module.explore-california-cluster.cluster_id
# }

# data "aws_availability_zones" "available" {
#   state = "available"
# }

# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
#   token                  = data.aws_eks_cluster_auth.cluster.token
#   config_path            = "~/.kube/config"
# }

# resource "aws_security_group" "enable_ssh" {
#   name_prefix = "worker_group_mgmt_one"
#   vpc_id      = module.explore-california-vpc.vpc_id

#   ingress {
#     from_port = 22
#     to_port   = 22
#     protocol  = "tcp"

#     cidr_blocks = [
#       "10.0.0.0/16"
#     ]
#   }
# }

# module "explore-california-vpc" {
#   source = "terraform-aws-modules/vpc/aws"

#   name = "explore-california"
#   cidr = "10.0.0.0/16"

#   azs             = slice(data.aws_availability_zones.available.names, 1, 3)
#   private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
#   public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
#   // These tags are required in order for the AWS ALB ingress controller to
#   // detect the subnets from which your targets will be pulled.
#   // https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
#   private_subnet_tags = {
#     "kubernetes.io/cluster/explore-california-cluster": "owned",
#     "kubernetes.io/role/elb": "1"
#   }
#   public_subnet_tags = {
#     "kubernetes.io/cluster/explore-california-cluster": "owned",
#     "kubernetes.io/role/elb": "1"
#   }

#   // The VPC needs to have access to the Internet and be able to assign DNS
#   // hostnames to EC2/adjacent instances within it for EKS workers to join your
#   // cluster (which isn't an EC2 instance set that you manage)
#   enable_nat_gateway = true
#   enable_vpn_gateway = true
#   enable_dns_support = true
#   enable_dns_hostnames = true
# }

# module "explore-california-cluster" {
#   source          = "./module"
#   cluster_name    = "explore-california-cluster"
#   cluster_version = "1.20"
#   subnets          = module.explore-california-vpc.public_subnets
#   vpc_id          = module.explore-california-vpc.vpc_id
#   worker_groups = [
#     {
#       instance_type = "t3.medium"
#       asg_max_size  = 5
#       spot_price = "0.02"
#       additional_security_group_ids = [ aws_security_group.enable_ssh.id ]
#       kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=spot"
#       suspended_processes = ["AZRebalance"]
#     },
#     {
#       instance_type = "t3.large"
#       asg_max_size  = 5
#       spot_price = "0.03"
#       additional_security_group_ids = [ aws_security_group.enable_ssh.id ]
#       kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=spot"
#       suspended_processes = ["AZRebalance"]
#     }
#   ]
# }

# resource "aws_ecr_repository" "explore-california" {
#   name = "explore-california"
#   image_tag_mutability = "MUTABLE"
#   image_scanning_configuration {
#     scan_on_push = true
#   }
# }
