# Configure AWS provider
provider "aws" {
  region = "us-east-1" # Update with your desired region
}

# VPC: Provides network isolation and connectivity for your EKS cluster and services.
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# EKS Cluster Authentication Token Data Source: retrieves an authentication token to communicate with the EKS cluster.
data "aws_eks_cluster_auth" "auth" {
  name = aws_eks_cluster.eks_cluster.name
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
  }
}

# Deploying the helm chart: -> fix....
resource "helm_release" "example" {
  name       = "example"
  repository = "https://charts.helm.sh/stable"
  chart      = "nginx"
  version    = "1.2.3"
  # namespace  = "default"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  # set {
  #   name  = "ingress.enabled"
  #   value = "true"
  # }

  # set {
  #   name  = "ingress.hosts[0].host"
  #   value = "pipeline.example.com"
  # }

  # set {
  #   name  = "ingress.hosts[0].paths[0]"
  #   value = "/"
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

# Public Subnets: host resources that need to be directly accessible from the internet
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count) # "10.0.${count.index}.0/24"
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
}

# Private Subnets: Host internal resources that shouldn't be directly accessible from the internet
resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count + 2)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

# Internet Gateway
# An Internet Gateway is attached to the VPC, allowing traffic to flow between the VPC and the internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
}

# NAT Gateway: Allows private subnets to access the internet while remaining private
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc = true
}

# Route Table for Public Subnets
# The public subnets have a route table associated with them that routes all outbound traffic to the Internet Gateway.
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_rt_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table for Private Subnets: Routes traffic to the NAT Gateway for internet access
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

# Associate Route Table with Private Subnets
resource "aws_route_table_association" "private_rt_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# EKS Node Group: Provides worker nodes for running your Kubernetes pods.
# Manages EC2 instances as worker nodes for the EKS cluster.
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = concat(aws_subnet.public_subnet[*].id, aws_subnet.private_subnet[*].id)
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

# Security Group for EKS Worker Nodes
resource "aws_security_group" "eks_worker_sg" {
  vpc_id = aws_vpc.eks_vpc.id

  #   ingress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "tcp"
  #   cidr_blocks = ["10.0.0.0/16"]  # Allow traffic within VPC
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for EKS Worker Nodes
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
}

# EKS Cluster: Hosts your Kubernetes control plane.
# Provisions an EKS cluster with the necessary networking and IAM roles.
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = concat(aws_subnet.public_subnet[*].id, aws_subnet.private_subnet[*].id)
    security_group_ids = [aws_security_group.eks_worker_sg.id]
  }
}

# IAM Role for EKS Cluster: Provides permissions for EKS and worker nodes.
resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
  ]
}

# Generate a random password for the database
resource "random_password" "db_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric  = true
}

# Generate a random username for the database
resource "random_password" "db_username" {
  length  = 12
  special = false
  upper   = true
  lower   = true
  numeric  = true
}

# Purpose: Manages your database for storing user data.
resource "aws_db_instance" "example" {
  identifier        = "example-db"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  username          = random_password.db_username.result
  password          = random_password.db_password.result
  db_name           = "exampledb"
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.db.id]
  subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow MySQL traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB Subnet Group for RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = aws_subnet.private_subnet[*].id
  description = "Private subnets for RDS"
}

# Outputs
output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "kubeconfig" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "vpc_id" {
  value = aws_vpc.eks_vpc.id
}

output "rds_endpoint" {
  value = aws_db_instance.example.endpoint
}

data "kubernetes_service" "frontend_service" {
  metadata {
    name      = "frontend-service"
    namespace = "default"
  }
}

output "frontend_loadbalancer_dns" {
  value = data.kubernetes_service.frontend_service.status[0].load_balancer[0].ingress[0].hostname
}

# output "rds_endpoint" {
#   value = aws_db_instance.default.endpoint
# }

# # Output EKS Cluster Endpoint and ARN
# output "eks_cluster_endpoint" {
#   value = aws_eks_cluster.eks_cluster.endpoint
# }

# output "eks_cluster_arn" {
#   value = aws_eks_cluster.eks_cluster.arn
# }

# output "az" {
#   value = data.aws_availability_zones.available.names[0]
# }

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "4.0.2"

#   name               = "kubernetes-iac-vpc"
#   cidr               = "172.17.0.0/16" # 10.0.0.0/16
#   azs                = [data.aws_availability_zones.available.names[0]] # slice(data.aws_availability_zones.available.names, 1, 3)
#   private_subnets    = ["172.17.1.0/24"] # ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
#   public_subnets     = ["172.17.100.0/24"] # ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
#   #   // These tags are required in order for the AWS ALB ingress controller to
#   #   // detect the subnets from which your targets will be pulled.
#   #   // https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
# #   private_subnet_tags = {
# #     "kubernetes.io/cluster/explore-california-cluster": "owned",
# #     "kubernetes.io/role/elb": "1"
# #   }
# #   public_subnet_tags = {
# #     "kubernetes.io/cluster/explore-california-cluster": "owned",
# #     "kubernetes.io/role/elb": "1"
# #   }
# #   // The VPC needs to have access to the Internet and be able to assign DNS
# #   // hostnames to EC2/adjacent instances within it for EKS workers to join your
# #   // cluster (which isn't an EC2 instance set that you manage)
# #   enable_vpn_gateway = true
# #   enable_dns_support = true
# #   enable_dns_hostnames = true
#   enable_nat_gateway = "true"
# }

# # ALB Ingress Controller
# module "alb_ingress_controller" {
#   source = "terraform-aws-modules/eks/aws//modules/alb-ingress-controller"
#   cluster_name       = aws_eks_cluster.eks_cluster.id
#   cluster_endpoint   = aws_eks_cluster.eks_cluster.endpoint
#   vpc_id             = aws_vpc.main_vpc.id
#   region             = "us-east-1" # Update with your desired region
#   oidc_provider_arn  = aws_iam_openid_connect_provider.eks.arn
#   aws_load_balancer_controller_version = "v2.2.3" # Update to the latest version
# }