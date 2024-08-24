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

# Example of customizing subnets in Terraform
# resource "aws_subnet" "private_subnet_a" {
#   vpc_id                  = aws_vpc.my_vpc.id
#   cidr_block              = "10.0.1.0/24"
#   availability_zone       = "us-east-1a"
#   map_public_ip_on_launch = false
#   tags = {
#     Name = "private-subnet-a"
#     kops.k8s.io/role = "node"
#   }
# }

# resource "aws_subnet" "public_subnet_a" {
#   vpc_id                  = aws_vpc.my_vpc.id
#   cidr_block              = "10.0.2.0/24"
#   availability_zone       = "us-east-1a"
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "public-subnet-a"
#     kops.k8s.io/role = "utility"
#   }
# }

# resource "aws_vpc" "main" {
#   cidr_block = "10.0.0.0/16"
# }

# resource "aws_internet_gateway" "gw" {
#   vpc_id = aws_vpc.main.id
# }

# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.gw.id
#   }
# }

# resource "aws_route_table_association" "public_association" {
#   subnet_id      = aws_subnet.public.id
#   route_table_id = aws_route_table.public.id
# }

# # VPC
# resource "aws_vpc" "k8s_vpc" {
#   cidr_block           = "10.0.0.0/16"
#   enable_dns_support   = true
#   enable_dns_hostnames = true
#   tags = {
#     Name = "k8s-vpc"
#   }
# }

# # Public Subnet (for Load Balancer)
# resource "aws_subnet" "public_subnet" {
#   vpc_id                  = aws_vpc.k8s_vpc.id
#   cidr_block              = "10.0.1.0/24"
#   map_public_ip_on_launch = true
#   availability_zone       = "us-east-1a"
#   tags = {
#     Name = "k8s-public-subnet"
#   }
# }

# # Private Subnet (for Microservices)
# resource "aws_subnet" "private_subnet" {
#   vpc_id            = aws_vpc.k8s_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-east-1a"
#   tags = {
#     Name = "k8s-private-subnet"
#   }
# }

# # Internet Gateway
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.k8s_vpc.id
#   tags = {
#     Name = "k8s-igw"
#   }
# }

# # Route Table for Public Subnet
# resource "aws_route_table" "public_rt" {
#   vpc_id = aws_vpc.k8s_vpc.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
#   tags = {
#     Name = "k8s-public-rt"
#   }
# }

# # Associate Public Subnet with Route Table
# resource "aws_route_table_association" "public_rt_assoc" {
#   subnet_id      = aws_subnet.public_subnet.id
#   route_table_id = aws_route_table.public_rt.id
# }

# # NAT Gateway for Private Subnet
# resource "aws_eip" "nat_eip" {
#   vpc = true
# }

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.public_subnet.id
# }

# # Route Table for Private Subnet
# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.k8s_vpc.id
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat_gw.id
#   }
#   tags = {
#     Name = "k8s-private-rt"
#   }
# }

# # Associate Private Subnet with Route Table
# resource "aws_route_table_association" "private_rt_assoc" {
#   subnet_id      = aws_subnet.private_subnet.id
#   route_table_id = aws_route_table.private_rt.id
# }

# output "vpc_id" {
#   value = aws_vpc.k8s_vpc.id
# }

# output "public_subnet_id" {
#   value = aws_subnet.public_subnet.id
# }

# output "private_subnet_id" {
#   value = aws_subnet.private_subnet.id
# }