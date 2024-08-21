provider "aws" {
  region = "us-east-1"
}

# Create S3 Bucket for Kops state storage
resource "aws_s3_bucket" "kops_state_store" {
  bucket = "your-kops-state-store"
  acl    = "private"
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

# VPC Configuration
resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id
}

# Subnets
resource "aws_subnet" "public_subnet" {
  count = 2
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = cidrsubnet(aws_vpc.k8s_vpc.cidr_block, 8, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_rt_assoc" {
  count = 2
  subnet_id = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for Kubernetes Nodes
resource "aws_security_group" "k8s_node_sg" {
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Output
output "vpc_id" {
  value = aws_vpc.k8s_vpc.id
}

output "public_subnets" {
  value = aws_subnet.public_subnet[*].id
}

output "security_group_id" {
  value = aws_security_group.k8s_node_sg.id
}

output "kops_state_store" {
  value = aws_s3_bucket.kops_state_store.bucket
}
