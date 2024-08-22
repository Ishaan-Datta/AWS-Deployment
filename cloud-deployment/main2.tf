# provider "aws" {
#   region = "us-west-2"  # Specify your region
# }

# # Toggle between Ingress Controller and Direct Load Balancer
# variable "use_ingress_controller" {
#   description = "Toggle to use Ingress Controller (true) or Direct Load Balancer (false)"
#   type        = bool
#   default     = true
# }

# # VPC
# resource "aws_vpc" "main_vpc" {
#   cidr_block = "10.0.0.0/16"
#   enable_dns_support = true
#   enable_dns_hostnames = true
#   tags = {
#     Name = "main_vpc"
#   }
# }

# # Subnets
# resource "aws_subnet" "public_subnet_1" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.1.0/24"
#   availability_zone = "us-west-2a"
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "public_subnet_1"
#   }
# }

# resource "aws_subnet" "public_subnet_2" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-west-2b"
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "public_subnet_2"
#   }
# }

# resource "aws_subnet" "private_subnet_1" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.3.0/24"
#   availability_zone = "us-west-2a"
#   tags = {
#     Name = "private_subnet_1"
#   }
# }

# resource "aws_subnet" "private_subnet_2" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.4.0/24"
#   availability_zone = "us-west-2b"
#   tags = {
#     Name = "private_subnet_2"
#   }
# }

# # Internet Gateway
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main_vpc.id
#   tags = {
#     Name = "main_igw"
#   }
# }

# # NAT Gateway
# resource "aws_eip" "nat_eip" {
#   vpc = true
# }

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.public_subnet_1.id
#   tags = {
#     Name = "nat_gw"
#   }
# }

# # Route Tables
# resource "aws_route_table" "public_rt" {
#   vpc_id = aws_vpc.main_vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }

#   tags = {
#     Name = "public_rt"
#   }
# }

# resource "aws_route_table_association" "public_rt_assoc_1" {
#   subnet_id      = aws_subnet.public_subnet_1.id
#   route_table_id = aws_route_table.public_rt.id
# }

# resource "aws_route_table_association" "public_rt_assoc_2" {
#   subnet_id      = aws_subnet.public_subnet_2.id
#   route_table_id = aws_route_table.public_rt.id
# }

# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.main_vpc.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat_gw.id
#   }

#   tags = {
#     Name = "private_rt"
#   }
# }

# resource "aws_route_table_association" "private_rt_assoc_1" {
#   subnet_id      = aws_subnet.private_subnet_1.id
#   route_table_id = aws_route_table.private_rt.id
# }

# resource "aws_route_table_association" "private_rt_assoc_2" {
#   subnet_id      = aws_subnet.private_subnet_2.id
#   route_table_id = aws_route_table.private_rt.id
# }

# # Security Groups
# resource "aws_security_group" "rds_sg" {
#   vpc_id = aws_vpc.main_vpc.id

#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/16"]  # Allow only from within the VPC
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "rds_sg"
#   }
# }

# resource "aws_security_group" "elb_sg" {
#   vpc_id = aws_vpc.main_vpc.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from anywhere
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "elb_sg"
#   }
# }

# resource "aws_security_group" "k8s_sg" {
#   vpc_id = aws_vpc.main_vpc.id

#   ingress {
#     from_port   = 0
#     to_port     = 65535
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/16"]  # Allow all traffic within the VPC
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "k8s_sg"
#   }
# }

# # Elastic Load Balancer
# resource "aws_elb" "frontend_elb" {
#   count = var.use_ingress_controller ? 0 : 1

#   name               = "frontend-elb"
#   subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
#   security_groups    = [aws_security_group.elb_sg.id]
#   availability_zones = ["us-west-2a", "us-west-2b"]

#   listener {
#     instance_port     = 80
#     instance_protocol = "HTTP"
#     lb_port           = 80
#     lb_protocol       = "HTTP"
#   }

#   health_check {
#     target              = "HTTP:80/"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Name = "frontend_elb"
#   }
# }

# kops cluster
# resource "null_resource" "kops_cluster" {
#   provisioner "local-exec" {
#     command = <<EOT
#       kops create cluster \
#         --name=mycluster.k8s.local \
#         --state=s3://my-kops-state-store \
#         --zones=us-west-2a,us-west-2b \
#         --node-count=2 \
#         --node-size=t3.medium \ 
#         --master-size=t3.medium \ # t3.nano
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
#   private_subnet_tags = {
#     "kubernetes.io/cluster/explore-california-cluster": "owned",
#     "kubernetes.io/role/elb": "1"
#   }
#   public_subnet_tags = {
#     "kubernetes.io/cluster/explore-california-cluster": "owned",
#     "kubernetes.io/role/elb": "1"
#   }
# #   // The VPC needs to have access to the Internet and be able to assign DNS
# #   // hostnames to EC2/adjacent instances within it for EKS workers to join your
# #   // cluster (which isn't an EC2 instance set that you manage)
#   enable_vpn_gateway = true
#   enable_dns_support = true
#   enable_dns_hostnames = true
#   enable_nat_gateway = "true"
# }


# secondary
# provider "aws" {
#   region = "us-west-2"  # Specify your region
# }

# # Toggle between Ingress Controller and Direct Load Balancer
# variable "use_ingress_controller" {
#   description = "Toggle to use Ingress Controller (true) or Direct Load Balancer (false)"
#   type        = bool
#   default     = true
# }

# # VPC
# resource "aws_vpc" "main_vpc" {
#   cidr_block = "10.0.0.0/16"
#   enable_dns_support = true
#   enable_dns_hostnames = true
#   tags = {
#     Name = "main_vpc"
#   }
# }

# # Subnets
# resource "aws_subnet" "public_subnet_1" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.1.0/24"
#   availability_zone = "us-west-2a"
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "public_subnet_1"
#   }
# }

# resource "aws_subnet" "public_subnet_2" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-west-2b"
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "public_subnet_2"
#   }
# }

# resource "aws_subnet" "private_subnet_1" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.3.0/24"
#   availability_zone = "us-west-2a"
#   tags = {
#     Name = "private_subnet_1"
#   }
# }

# resource "aws_subnet" "private_subnet_2" {
#   vpc_id            = aws_vpc.main_vpc.id
#   cidr_block        = "10.0.4.0/24"
#   availability_zone = "us-west-2b"
#   tags = {
#     Name = "private_subnet_2"
#   }
# }

# # Internet Gateway
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main_vpc.id
#   tags = {
#     Name = "main_igw"
#   }
# }

# # NAT Gateway
# resource "aws_eip" "nat_eip" {
#   vpc = true
# }

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.public_subnet_1.id
#   tags = {
#     Name = "nat_gw"
#   }
# }

# # Route Tables
# resource "aws_route_table" "public_rt" {
#   vpc_id = aws_vpc.main_vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }

#   tags = {
#     Name = "public_rt"
#   }
# }

# resource "aws_route_table_association" "public_rt_assoc_1" {
#   subnet_id      = aws_subnet.public_subnet_1.id
#   route_table_id = aws_route_table.public_rt.id
# }

# resource "aws_route_table_association" "public_rt_assoc_2" {
#   subnet_id      = aws_subnet.public_subnet_2.id
#   route_table_id = aws_route_table.public_rt.id
# }

# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.main_vpc.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat_gw.id
#   }

#   tags = {
#     Name = "private_rt"
#   }
# }

# resource "aws_route_table_association" "private_rt_assoc_1" {
#   subnet_id      = aws_subnet.private_subnet_1.id
#   route_table_id = aws_route_table.private_rt.id
# }

# resource "aws_route_table_association" "private_rt_assoc_2" {
#   subnet_id      = aws_subnet.private_subnet_2.id
#   route_table_id = aws_route_table.private_rt.id
# }

# # Security Groups
# resource "aws_security_group" "rds_sg" {
#   vpc_id = aws_vpc.main_vpc.id

#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/16"]  # Allow only from within the VPC
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "rds_sg"
#   }
# }

# resource "aws_security_group" "elb_sg" {
#   vpc_id = aws_vpc.main_vpc.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from anywhere
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "elb_sg"
#   }
# }

# resource "aws_security_group" "k8s_sg" {
#   vpc_id = aws_vpc.main_vpc.id

#   ingress {
#     from_port   = 0
#     to_port     = 65535
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/16"]  # Allow all traffic within the VPC
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "k8s_sg"
#   }
# }

# # RDS Instance
# resource "aws_db_instance" "rds" {
#   allocated_storage    = 20
#   storage_type         = "gp2"
#   engine               = "mysql"
#   engine_version       = "8.0"
#   instance_class       = "db.t3.micro"
#   name                 = "mydatabase"
#   username             = "admin"
#   password             = "password"
#   parameter_group_name = "default.mysql8.0"
#   publicly_accessible  = false
#   skip_final_snapshot  = true

#   vpc_security_group_ids = [aws_security_group.rds_sg.id]

#   db_subnet_group_name = aws_db_subnet_group.main.name

#   tags = {
#     Name = "rds_instance"
#   }
# }

# resource "aws_db_subnet_group" "main" {
#   name       = "main"
#   subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

#   tags = {
#     Name = "main"
#   }
# }

# # Elastic Load Balancer
# resource "aws_elb" "frontend_elb" {
#   count = var.use_ingress_controller ? 0 : 1

#   name               = "frontend-elb"
#   subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
#   security_groups    = [aws_security_group.elb_sg.id]
#   availability_zones = ["us-west-2a", "us-west-2b"]

#   listener {
#     instance_port     = 80
#     instance_protocol = "HTTP"
#     lb_port           = 80
#     lb_protocol       = "HTTP"
#   }

#   health_check {
#     target              = "HTTP:80/"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Name = "frontend_elb"
#   }
# }

# # Outputs
# output "vpc_id" {
#   value = aws_vpc.main_vpc.id
# }

# output "rds_endpoint" {
#   value = aws_db_instance.rds.endpoint
# }

# output "elb_dns_name" {
#   value = var.use_ingress_controller ? "" : aws_elb.frontend_elb.dns_name
# }

# provider "aws" {
#   region = "us-east-1"
# }

# # Create S3 Bucket for Kops state storage
# resource "aws_s3_bucket" "kops_state_store" {
#   bucket = "your-kops-state-store"
#   acl    = "private"
# }

# # IAM Role for Kops cluster management
# resource "aws_iam_role" "kops_role" {
#   name = "kops-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = "sts:AssumeRole",
#       Effect = "Allow",
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#     }]
#   })
  
#   managed_policy_arns = [
#     "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
#     "arn:aws:iam::aws:policy/AmazonS3FullAccess",
#     "arn:aws:iam::aws:policy/IAMFullAccess",
#     "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
#   ]
# }

# # VPC Configuration
# resource "aws_vpc" "k8s_vpc" {
#   cidr_block = "10.0.0.0/16"
#   enable_dns_support = true
#   enable_dns_hostnames = true
# }

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.k8s_vpc.id
# }

# # Subnets
# resource "aws_subnet" "public_subnet" {
#   count = 2
#   vpc_id = aws_vpc.k8s_vpc.id
#   cidr_block = cidrsubnet(aws_vpc.k8s_vpc.cidr_block, 8, count.index)
#   availability_zone = element(data.aws_availability_zones.available.names, count.index)
#   map_public_ip_on_launch = true
# }

# # Route Table for Public Subnet
# resource "aws_route_table" "public_rt" {
#   vpc_id = aws_vpc.k8s_vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
# }

# # Associate Route Table with Public Subnets
# resource "aws_route_table_association" "public_rt_assoc" {
#   count = 2
#   subnet_id = aws_subnet.public_subnet[count.index].id
#   route_table_id = aws_route_table.public_rt.id
# }

# # Security Group for Kubernetes Nodes
# resource "aws_security_group" "k8s_node_sg" {
#   vpc_id = aws_vpc.k8s_vpc.id

#   ingress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # Output
# output "vpc_id" {
#   value = aws_vpc.k8s_vpc.id
# }

# output "public_subnets" {
#   value = aws_subnet.public_subnet[*].id
# }

# output "security_group_id" {
#   value = aws_security_group.k8s_node_sg.id
# }

# output "kops_state_store" {
#   value = aws_s3_bucket.kops_state_store.bucket
# }

# helm install nginx-ingress ingress-nginx/ingress-nginx \
#   --set controller.service.type=LoadBalancer \
#   --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-internal"="false" \
#   --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="classic"