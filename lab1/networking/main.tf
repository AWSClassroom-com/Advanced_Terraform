# lab1-networking/main.tf
#
# Simulates "the networking team's" VPC — owned by a different team, deployed
# infrequently, consumed by every application team via terraform_remote_state.
#
# Outputs (defined in outputs.tf): vpc_id, subnet_id, security_group_id

resource "aws_vpc" "shared" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${var.account}-shared-vpc"
    Purpose   = "shared-networking"
  }
}

resource "aws_internet_gateway" "shared" {
  vpc_id = aws_vpc.shared.id

  tags = {
    Name = "${var.account}-shared-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.shared.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.account}-shared-public"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.shared.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shared.id
  }

  tags = {
    Name = "${var.account}-shared-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "shared_app" {
  name_prefix = "${var.account}-shared-app-"
  description = "Default app security group exposed to consumers via remote state"
  vpc_id      = aws_vpc.shared.id

  # HTTP from anywhere (lab only — production would restrict)
  ingress {
    description = "HTTP from world (lab)"
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
    Name = "${var.account}-shared-app-sg"
  }
}
