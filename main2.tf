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