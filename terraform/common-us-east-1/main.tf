provider "aws" {
  region = "us-east-1"
}

# This is the shared resources bucket key -- you will need it across environments
data "terraform_remote_state" "shared_resources" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/shared_resources.tfstate"
    region = "us-east-1"
  }
}

# This is the bucket holding this specific tfstate
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/us-east-1-common.tfstate"
    region = "us-east-1"
  }
}

# VPC for us-east-1 (10.4.0.0/16 — avoids 10.3/16 us-east-2, 10.0/16 eu-west-1)
resource "aws_vpc" "perf_cto_vpc" {
  cidr_block           = "10.4.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "perf-cto-vpc-us-east-1"
    Environment = "performance-cto"
    Project     = "performance-cto"
  }
}

# Subnets in 2 AZs (Aurora requires at least 2)
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.perf_cto_vpc.id
  cidr_block              = "10.4.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "perf-cto-subnet-us-east-1a"
    Environment = "performance-cto"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.perf_cto_vpc.id
  cidr_block              = "10.4.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "perf-cto-subnet-us-east-1b"
    Environment = "performance-cto"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "perf_cto_gw" {
  vpc_id = aws_vpc.perf_cto_vpc.id

  tags = {
    Name        = "perf-cto-igw-us-east-1"
    Environment = "performance-cto"
  }
}

# Route table with default route to IGW
resource "aws_route_table" "perf_cto_rt" {
  vpc_id = aws_vpc.perf_cto_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.perf_cto_gw.id
  }

  tags = {
    Name        = "perf-cto-rt-us-east-1"
    Environment = "performance-cto"
  }
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.perf_cto_rt.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.perf_cto_rt.id
}

# Security group
resource "aws_security_group" "perf_cto_sg" {
  name        = "perf-cto-sg-us-east-1"
  description = "Performance CTO security group for us-east-1"
  vpc_id      = aws_vpc.perf_cto_vpc.id

  # SSH
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL
  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All traffic within VPC
  ingress {
    description = "All TCP within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.4.0.0/16"]
  }

  ingress {
    description = "All UDP within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["10.4.0.0/16"]
  }

  # All traffic within 10.0.0.0/8 (cross-region internal)
  ingress {
    description = "All TCP internal"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  # Outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "perf-cto-sg-us-east-1"
    Environment = "performance-cto"
    Project     = "performance-cto"
  }
}

# DB subnet group for Aurora (requires subnets in at least 2 AZs)
resource "aws_db_subnet_group" "perf_cto_db_subnet_group" {
  name       = "perf-cto-us-east-1-db-subnetgroup"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  tags = {
    Name        = "perf-cto-us-east-1-db-subnetgroup"
    Environment = "performance-cto"
  }
}

# Outputs for use by other deployments
output "perf_cto_vpc_id" {
  value       = aws_vpc.perf_cto_vpc.id
  description = "VPC ID for us-east-1"
}

output "perf_cto_sg_id" {
  value       = aws_security_group.perf_cto_sg.id
  description = "Security group ID for us-east-1"
}

output "subnet_us_east_1a_id" {
  value       = aws_subnet.subnet_a.id
  description = "Subnet ID for us-east-1a"
}

output "subnet_us_east_1b_id" {
  value       = aws_subnet.subnet_b.id
  description = "Subnet ID for us-east-1b"
}

output "db_subnet_group_name" {
  value       = aws_db_subnet_group.perf_cto_db_subnet_group.name
  description = "DB subnet group name for Aurora/RDS"
}

output "igw_id" {
  value       = aws_internet_gateway.perf_cto_gw.id
  description = "Internet gateway ID"
}
