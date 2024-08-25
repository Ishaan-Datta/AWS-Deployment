resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, {
    Name               = "${var.vpc_name}"
  })
}

resource "aws_subnet" "public_subnet" {
  count                                                = var.az_count
  vpc_id                                               = aws_vpc.main_vpc.id
  cidr_block                                           = var.public_subnet_cidr_blocks[count.index]
  availability_zone                                    = element(var.azs, count.index)
  map_public_ip_on_launch                              = true
  tags                                                 = merge(var.tags, {
    Name                                               = "${var.vpc_name}-public-subnet-${count.index + 1}" 
    "kubernetes.io/cluster/${var.kops_cluster_name}"   = "owned"
    "kubernetes.io/role/elb"                           = "1"
    "kubernetes.io/role/internal-elb"                  = "0"
    "kops.k8s.io/role"                                 = "utility"
  })
}

resource "aws_subnet" "private_subnet" {
  count                                              = var.az_count
  vpc_id                                             = aws_vpc.main_vpc.id
  cidr_block                                         = var.private_subnet_cidr_blocks[count.index]
  availability_zone                                  = element(var.azs, count.index)
  tags                                               = merge(var.tags, {
    Name                                             = "${var.vpc_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.kops_cluster_name}" = "owned"
    kops.k8s.io/role                                 = "node"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

resource "aws_eip" "nat_eip" {
  count  = var.az_count
  tags   = merge(var.tags, {
    Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "nat_gw" {
  count         = var.az_count
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id
  tags          = merge(var.tags, {
    Name        = "${var.vpc_name}-nat-gw-${count.index + 1}"
  })
}

resource "aws_route_table" "public_rt" {
  vpc_id       = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags         = merge(var.tags, {
    Name       = "${var.vpc_name}-public-rt"
  })
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = var.az_count
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  count            = var.az_count
  vpc_id           = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }
  tags             = merge(var.tags, {
    Name           = "${var.vpc_name}-private-rt"
  })
}

resource "aws_route_table_association" "private_rt_assoc" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "k8s_sg" {
  vpc_id        = aws_vpc.main_vpc.id
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
  tags          = merge(var.tags, {
    Name        = "${var.vpc_name}-k8s-sg"
  })
}