# lab2-import/network.tf
#
# Cleaned VPC configuration for the imported resources. This is what the
# Terraform state will look like AFTER import — it must match the actual
# AWS reality so `terraform plan` shows "0 to change" once imports complete.
#
# Compare to lab2-day1-vpc-lean/custom-vpc.tf (or aws/vpc/custom-vpc.tf in
# the Day 1-2 repo): same resource addresses, same essential attributes,
# minus computed fields (arn, id, owner_id) that auto-generated config
# would have included. This is the "cleanup pattern" Module 2 teaches.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "custom-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.account}-vpc"
  }

  lifecycle {
    # Will be added in a later step; commented for now so the initial import succeeds.
    # Once imported and verified, uncomment to protect against accidental destroy.
    # prevent_destroy = true
  }
}

resource "aws_subnet" "subnet-a" {
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.account}-public-subnet-a"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.account}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.account}-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_a" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.public_rt.id
}
