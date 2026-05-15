# modules/app/main.tf
#
# Sample web application — VPC + public subnet + EC2 instance with Apache
# (mirrors the Day 1-2 lab pattern). Used by environments/staging/ and
# environments/prod/ wrappers; the only inputs that change between envs are
# var.environment (subnet CIDR derives from it) and the AWS provider region
# (set in the wrapper).
#
# Resources created per environment (7 total):
#   1. aws_vpc
#   2. aws_subnet (public)
#   3. aws_internet_gateway
#   4. aws_route_table
#   5. aws_route_table_association
#   6. aws_security_group (HTTP-only inbound)
#   7. aws_instance (t3.micro with httpd + index.html)

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  # Staging and prod each get a distinct /16 inside the 10.0.0.0/8 block.
  # This avoids any CIDR overlap with Day 1-2's 192.168.0.0/20 baseline
  # and lets a single AWS account host both environments side-by-side
  # without VPC peering / route conflicts.
  vpc_cidr    = var.environment == "prod" ? "10.20.0.0/16" : "10.10.0.0/16"
  subnet_cidr = var.environment == "prod" ? "10.20.1.0/24" : "10.10.1.0/24"
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.student_id}-${var.environment}-vpc"
    Environment = var.environment
    Student     = var.student_id
    ManagedBy   = "terraform-pipeline"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.student_id}-${var.environment}-public-subnet"
    Student = var.student_id
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.student_id}-${var.environment}-igw"
    Student = var.student_id
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.student_id}-${var.environment}-public-rt"
    Student = var.student_id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "${var.student_id}-${var.environment}-web-sg"
  description = "Allow HTTP inbound; all outbound. Created by Lab 3 pipeline."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.student_id}-${var.environment}-web-sg"
    Student = var.student_id
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  # AL2023 user_data: dnf (not yum), httpd, env-tagged index.html.
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y httpd
    systemctl enable --now httpd
    cat > /var/www/html/index.html <<HTML
    <h1>Sample Web App</h1>
    <p>Environment: ${var.environment}</p>
    <p>Student: ${var.student_id}</p>
    <p>Deployed via CI/CD Pipeline</p>
    HTML
  EOF

  tags = {
    Name        = "${var.student_id}-${var.environment}-web"
    Environment = var.environment
    Student     = var.student_id
    ManagedBy   = "terraform-pipeline"
  }
}
