# To deploy your microservice architecture on an Amazon EKS (Elastic Kubernetes Service) 
# cluster with an Ingress controller, the Terraform template will be updated accordingly. 
# Below is the Terraform configuration that provisions all required AWS resources, including the 
# EKS cluster, node groups, security groups, and an RDS instance. Additionally, it includes an Ingress 
# controller setup using an AWS Load Balancer.

provider "aws" {
  region = "us-west-2"
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnet for EKS Worker Nodes
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

# Private Subnets for EKS Worker Nodes
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-2b"
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Public Route Table with Public Subnet
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "microservice-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet.id,
      aws_subnet.private_subnet_1.id,
      aws_subnet.private_subnet_2.id,
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policy]
}

# IAM Role for EKS Cluster
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
}

# Attach EKS Policies to EKS Role
resource "aws_iam_role_policy_attachment" "eks_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_role.name
}

# Node Group for EKS Cluster
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_subnet.id, aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [aws_eks_cluster.eks_cluster]
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
}

# Attach EKS Worker Node Policies to Node Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# RDS Instance for User Database
resource "aws_db_instance" "user_db" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  name                 = "userdb"
  username             = "admin"
  password             = "yourpassword"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.internal_sg.id]
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

# Security Groups

## Security Group for EKS Nodes
resource "aws_security_group" "eks_node_sg" {
  vpc_id = aws_vpc.main_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Internal communication within the VPC
  }
}

## Security Group for RDS (User Database)
resource "aws_security_group" "internal_sg" {
  vpc_id = aws_vpc.main_vpc.id

  # Allow internal communication
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Outbound to the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AWS Load Balancer Controller IAM Role for Ingress Controller
resource "aws_iam_policy" "alb_controller_policy" {
  name        = "ALBIngressControllerIAMPolicy"
  description = "Policy for ALB Ingress Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "elasticloadbalancing:*"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroupRules",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "alb_controller_role" {
  name               = "ALBIngressControllerRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "alb_controller_policy_attachment" {
  role       = aws_iam_role.alb_controller_role.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}

# Outputs
output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "kubeconfig" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

# You don't usually need to configure security groups manually for the Load Balancer unless you have 
# specific network requirements or constraints. AWS handles the creation and basic configuration of the 
# security groups associated with the Load Balancer automatically.

# defininig load balancer + security group:
resource "aws_security_group" "frontend_lb_sg" {
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# If you use HTTPS (port 443), you will need an SSL/TLS certificate: either through AWS Certificate Manager 
# (ACM) or another certificate provider. This certificate will handle the encryption of traffic on port 443.

# NodePort: Exposes the service on a port on each node. Ensure security groups allow traffic to the nodes on the specified port.

# will need to define load balancer if using ingress... and the accompanying security group
# load balancer -> ingress controller -> nodeport 
# does it need to be nodeport or can it be all clusterip

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.eks.id]
  subnets            = aws_subnet.public[*].id
}