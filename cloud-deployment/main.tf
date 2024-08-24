terraform {
  backend "s3" {
    bucket = "tf-state-blog" # replace
    key    = "dev/terraform"
    region = "eu-west-2"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

variable "az_count" {
  type = number
  default = 3
}

locals { 
  azs =  slice(data.aws_availability_zones.available.names, 0, 3)
  environment = "dev"
  kops_state_bucket_name = "${random_string.random.result}-kops-bucket"
  kubernetes_cluster_name = "kops-cluster-${random_string.random.result}.k8s.local"
  vpc_name = "idfk"
  # need to keep ingress ips?

  tags = {
    terraform = true
    environment = "dev"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "1.46.0"
  name = "${local.vpc_name}"
  cidr = "10.0.0.0/16"
  azs                = ["${local.azs}"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] # use generation
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"] # use generation
  enable_nat_gateway = true
#   enable_dns_support = true
#   enable_dns_hostnames = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.kubernetes_cluster_name}" = "owned"
    "kubernetes.io/role/elb" = "1"
  }

    tags = {
    "kubernetes.io/cluster/${local.kubernetes_cluster_name}" = "shared"
    "terraform"                                              = true
    "environment"                                            = "${local.environment}"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.kubernetes_cluster_name}" = "owned"
    "kubernetes.io/role/elb" = true
  }
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  count = 2
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = cidrsubnet(aws_vpc.k8s_vpc.cidr_block, 8, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24" # public subnet number two is 10.0.2.0/24
# private subnet would be 10.0.3.0/24
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private_rt"
  }
}

resource "aws_security_group" "k8s_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow all traffic within the VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s_sg"
  }
}

# Create S3 Bucket for Kops state storage need to turn on versioning
resource "aws_s3_bucket" "kops_state_store" {
  bucket = "${local.kops_state_bucket_name}"
  acl    = "private"
  force_destroy = true
  tags = "${merge(local.tags)}"
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

resource "null_resource" "kops_cluster" {
  provisioner "local-exec" {
    command = <<EOT
      kops create cluster \
        --name=${var.kops_cluster_name} \
        --state=${var.kops_state_store} \
        --zones=${var.aws_zones} \
        --node-count=1 \
        --node-size=t3.medium \
        --master-size=t3.medium \
        --vpc=${aws_vpc.main_vpc.id} \
        --subnets=${aws_subnet.private_subnet_1.id},${aws_subnet.private_subnet_2.id} \
        --out=kops-terraform/
      
      kops update cluster --name=mycluster.k8s.local --yes
      kops export kubecfg --name=mycluster.k8s.local
    EOT
  }

  triggers = {
    cluster_update = "${timestamp()}"
  }

  depends_on = [aws_vpc.main_vpc]
}

resource "helm_release" "nginx_ingress" {
  # conditionally deploying ingress helm chart if use_ingress_controller is true
  count     = var.use_ingress_controller ? 1 : 0

  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx/"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service.beta.kubernetes.io/aws-load-balancer-internal"
    value = "false"
  }

  set {
    name = "controller.service.annotations.service.beta.kubernetes.io/aws-load-balancer-type"
    value = "classic"
  }
}

# populate from helm.sh repo
resource "helm_release" "helm_deployment" {
  name       = "helm_deployment"
  repository = "https://example.com/charts"
  chart      = "backend-app"
  namespace  = "default"

  values = [
    file("backend-values.yaml")
  ]
}

resource "null_resource" "wait_for_lb" {
  provisioner "local-exec" {
    command = "sleep 30"
  }

  depends_on = [helm_release.helm_deployment]
}

// Filtering by Tags: If the LoadBalancer name is not unique, you can filter by tags that Kubernetes typically applies to the LoadBalancer, such as kubernetes.io/service-name.

# data "aws_lb" "nginx_lb" {
#   name = helm_release.nginx_ingress.name
# }

# output "nginx_ingress_url" {
#   value = data.aws_lb.nginx_lb.dns_name
# }