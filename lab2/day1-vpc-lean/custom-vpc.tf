# lab2-day1-vpc-lean/custom-vpc.tf
#
# This is a copy of aws/vpc/custom-vpc.tf from the Day 1-2 repo, with the
# NAT gateway commented out. Students who already deployed the full Day 1-2
# VPC can skip this and import their existing resources directly. Students
# who don't have it running deploy this lean version (~$0/hour) and import.
#
# Source: https://github.com/AWSClassroom-com/hands-on-terraform/blob/main/aws/vpc/custom-vpc.tf
#
# What changed from the Day 1-2 original:
#   - Removed `aws_nat_gateway.ngw` (NAT GW is ~$1/day; not needed for the import lab)
#   - Removed the EIP that the NAT GW used
# Everything else (resource names, tags, CIDRs) is identical so the import
# blocks in lab2-import/ work against either this lean version OR the original.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "custom-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.user_id}-${var.vpc_name}"
  }
}

resource "aws_subnet" "subnet-a" {
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.user_id}-${var.public_subnet_a_name}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.user_id}-igw"
  }
}

# NAT gateway removed in lean version — uncomment to match full Day 1-2 stack.
# resource "aws_nat_gateway" "ngw" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.subnet-a.id
#   tags = {
#     Name = "${var.user_id}-ngw"
#   }
# }

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.user_id}-${var.route_table_name}"
  }
}

resource "aws_route_table_association" "public_subnet_a" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.public_rt.id
}
