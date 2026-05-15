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

# Look up the imported subnet's ACTUAL availability_zone rather than guessing
# from `aws_availability_zones.available.names[0]`. The AZ ordering returned
# by `aws_availability_zones` is not guaranteed to match what was deployed
# at create time (AWS can mark zones impaired or add new ones), so anchoring
# the resource's `availability_zone` to a static index would produce a
# spurious destroy+recreate diff on `terraform plan` after import. Reading
# from the live subnet via data source guarantees "0 to change".
data "aws_subnet" "imported" {
  id = var.subnet_id
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
  availability_zone       = data.aws_subnet.imported.availability_zone
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
