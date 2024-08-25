terraform {
  required_providers {
    aws = {
      version = "4.67.0"
    }
  }
}

provider "aws" {
  alias = "aws-region-provider"
  region = "ca-central-1"
}

provider "kubernetes" {
    config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

data "aws_regions" "available" {}

variable "aws_region" {
  description = "The AWS region in which to deploy the resources"
  type    = string
  default = "us-east-2"
  
  validation {
    condition     = contains(data.aws_regions.available.names, var.aws_region)
    error_message = "Invalid AWS region. Please provide a valid AWS region from the available regions."
  }
}

variable "az_count" {
  description = "The number of availability zones to use (1-5)"
  type    = number
  default = 3

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 5
    error_message = "The number of AZs must be between 1 and 5."
  }
}

variable "use_ingress_controller" {
  description = "Toggle to use Ingress Controller (true) or Direct Load Balancer (false)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "The name of the Terraform environment to create resources under"
  type    = string
  default = "dev"
}

variable "namespace" {
  description = "The namespace to deploy the Helm chart to"
  type    = string
  default = "AWS-Deployment"
}

variable "deployment_name" {
  description = "The name of the deployment"
  type    = string
  default = "AWS-Deployment"
}

variable "vpc_name" {
  description = "The name of the VPC"
  type   = string
  default = "vpc-dev"
}

variable "ssh_key_path" {
  description = "The path to the SSH public key to be used for the bastion hosts"
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_string" "random" {
  length  = 16
  lower   = true
  upper   = false
  special = false
  numeric = false
}

locals { 
  azs =  slice(data.aws_availability_zones.available.names, 0, var.az_count)
  environment = "${var.environment}"
  kops_cluster_name = "kops-cluster-${random_string.random.result}.k8s.local"
  kops_state_store_name = "${random_string.random.result}-kops-bucket"
  kops_state_store = "s3://${locals.kops_state_store_name}"
  tags = {
    terraform = true
    environment = "${var.environment}"
  }
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet("10.0.0.0/16", 8, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet("10.0.0.0/16", 8, i + var.az_count)]
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${var.vpc_name}"
  })
}

resource "aws_subnet" "public_subnet" {
  count = var.az_count
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = local.public_subnet_cidrs[count.index]
  availability_zone = element(local.azs, count.index)
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-public-subnet-${count.index + 1}" 
    "kubernetes.io/cluster/${local.kops_cluster_name}" = "owned"
    "kubernetes.io/role/elb" = true
    kops.k8s.io/role = "utility"
  })
}

resource "aws_subnet" "private_subnet" {
  count = var.az_count

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    "Name"                                       = "${vpc_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${local.kops_cluster_name}" = "owned"
    kops.k8s.io/role = "node"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = merge(local.tags, {
    Name = "${vpc_name}-igw"
  })
}

# NAT EIP
resource "aws_eip" "nat_eip" {
  count = var.az_count
  tags = merge(local.tags, {
    Name = "${vpc_name}-nat-eip-${count.index + 1}"
  })
}

# NAT gateway
resource "aws_nat_gateway" "nat_gw" {
  count = var.az_count

  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id

  tags = merge(local.tags, {
    Name = "${vpc_name}-nat-gw-${count.index + 1}"
  })
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.tags, {
    Name = "${vpc_name}-public-rt"
  })
}

resource "aws_route_table_association" "public_rt_assoc" {
  count = var.az_count

  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = merge(local.tags, {
    Name = "${vpc_name}-private-rt"
  })
}

resource "aws_route_table_association" "private_rt_assoc" {
  count = var.az_count

  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
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

  tags = merge(local.tags, {
    Name = "${vpc_name}-k8s-sg"
  })
}

# Create S3 Bucket for Kops state storage need to turn on versioning
resource "aws_s3_bucket" "kops_state_store" {
  provider = aws.aws-region-provider
  bucket   = locals.kops_state_store_name
  force_destroy = true
  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "example" {
  provider = aws.aws-region-provider
  bucket   = aws_s3_bucket.kops_state_store.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "example" {
  provider = aws.aws-region-provider
  bucket   = aws_s3_bucket.kops_state_store.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  provider = aws.aws-region-provider
  depends_on = [
    aws_s3_bucket_public_access_block.example,
    aws_s3_bucket_ownership_controls.example,
  ]

  bucket = aws_s3_bucket.kops_state_store.id
  acl    = "public-read"
}

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
        --name=${local.kops_cluster_name} \
        --state=${local.kops_state_store} \
        --zones=${local.azs} \
        --networking=kuberouter \
        --vpc=${aws_vpc.main_vpc.id} \
        --subnets=${join(",", aws_subnet.private_subnet.*.id)} \
        --utility-subnets=${join(",", aws_subnet.public_subnet.*.id)} \
        --topology=private \
        --bastion \
        --ssh-public-key=${ssh_key_path} \
        --node-count=1 \
        --node-size=t3.small \ 
        --master-size=t3.medium \
      kops update cluster --name=${local.kops_cluster_name} --yes --state=${local.kops_state_store} --admin
      kops validate cluster --name=${local.kops_cluster_name} --state=${local.kops_state_store} --wait 10m
      kops export kubecfg --admin --name=${local.kops_cluster_name} --state=${local.kops_state_store}
    EOT
  }

  depends_on = [
    aws_vpc.main_vpc,
    aws_subnet.public,
    aws_subnet.private,
    aws_s3_bucket.kops_state_store
  ]
}

resource "kubernetes_namespace" "my_namespace" {
  metadata {
    name = "${var.namespace}"
  }

  depends_on = [null_resource.kops_cluster]
}

resource "helm_release" "nginx_ingress" {
  count     = var.use_ingress_controller ? 1 : 0

  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx/"
  chart      = "ingress-nginx"
  namespace  = "${var.namespace}"

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

  depends_on = [ null_resource.kops_cluster ]
}

# populate from helm.sh repo
resource "helm_release" "helm_deployment" {
  name       = "${var.deployment_name}"
  repository = "https://example.com/charts"
  chart      = "backend-app"
  namespace  = "${var.namespace}"

  set {
    name = "deployment.ingressEnabled"
    value = false
  }

  set {
    name = "deployment.localTesting"
    value = false
  }

  set {
    name = "deployment.replicaCount"
    value = "${var.az_count}"
  }

  depends_on = [ null_resource.kops_cluster ]
}

resource "null_resource" "wait_for_lb" {
  provisioner "local-exec" {
    command = "sleep 30"
  }

  depends_on = [helm_release.helm_deployment]
}

resource "null_resource" "fetch_elb_urls" {
  provisioner "local-exec" {
    command = <<EOT
      NAMESPACE="${var.namespace}"
      
      # Fetch the LoadBalancer services in the specified namespace
      kubectl get services -n $NAMESPACE -o json | jq -r '
      .items[] | select(.spec.type == "LoadBalancer") | 
      "\(.metadata.name) - \(.status.loadBalancer.ingress[] | .hostname // .ip)"' > elb_urls.txt
      
      # Output the first result
      head -n 1 elb_urls.txt
    EOT
  }
}

output "cluster_name" {
  value = locals.kops_cluster_name
}

output "kops_state_store_name" {
  value = locals.kops_state_store_name
}

output "kops_state_store_bucket" {
  value = locals.kops_state_store
}

output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "public_subnets_ids" {
  value = aws_subnet.public_subnet[*].id
}

output "public_subnets_cidr_blocks" {
  value = locals.public_subnets_cidrs
}

output "private_subnets_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "public_subnets_cidr_blocks" {
  value = locals.private_subnets_cidrs
}

output "availability_zones" {
  value = locals.azs
}

output "environment" {
  value = locals.environment
}

output "namespace" {
  value = vars.namespace
}