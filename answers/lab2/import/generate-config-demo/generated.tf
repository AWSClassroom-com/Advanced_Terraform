# answers/lab2 — generate-config-demo/generated.tf
#
# The Lab 2 Challenge: what `terraform plan -generate-config-out=generated.tf`
# wrote, after cleanup. Running `terraform plan` in this folder with this file
# in place gives:
#
#   Plan: 9 to import, 0 to add, 0 to change, 0 to destroy.
#
# What cleanup removed, and why:
#   - every computed / read-only attribute (arn, owner_id, id, tags_all)
#   - every argument left at its type's empty value because the real resource
#     never set it (enable_lni_at_device_index = 0, "" CIDRs)
#   - availability_zone_id, which conflicts with availability_zone; the data
#     source below reads the live subnet's AZ instead, which is what makes
#     "0 to change" reliable regardless of how AWS orders zones
#   - hardcoded "vpc-0abc..." strings, replaced with references so the file
#     describes the dependencies rather than restating today's IDs
#
# The CIDRs are literals here because this folder declares no vpc_cidr /
# public_subnet_cidr variables. The shipped lab2/import/network.tf takes the
# extra step of moving them into variables — worth doing, and the reason the
# main import directory has those two variables and this one does not.

data "aws_subnet" "imported" {
  id = var.subnet_id
}

resource "aws_vpc" "custom-vpc" {
  cidr_block           = "192.168.0.0/20"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.user_id}-vpc"
  }

}

resource "aws_subnet" "subnet-a" {
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = "192.168.0.0/24"
  availability_zone       = data.aws_subnet.imported.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.user_id}-public-subnet-a"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.user_id}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.user_id}-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_a" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "allow-http-ssh" {
  name        = "${var.user_id}-allow-http-ssh"
  description = "Enable HTTP and SSH Access"
  vpc_id      = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.user_id}-allow-http-ssh"
  }

}

resource "aws_vpc_security_group_ingress_rule" "allow-http-ipv4" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh-ipv4" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow-all-outbound" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
