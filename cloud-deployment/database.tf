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
  engine            = "postgres"
  instance_class    = "db.t3.micro"
  allocated_storage = 20 # might cost money
  username          = random_password.db_username.result
  password          = random_password.db_password.result
  db_name           = "exampledb"
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.db.id]

  db_subnet_group_name = aws_db_subnet_group.main.name

  tags = {
    Name = "rds_instance"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "main"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow pgSQL traffic"
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

output "rds_endpoint" {
  value = aws_db_instance.example.endpoint
}

output "rds_username" {
  value = random_password.db_username.result
}

output "rds_password" {
  value = random_password.db_password.result
}

output "rds_db_name" {
  value = aws_db_instance.example.db_name
}