# lab2/import/imports.tf
#
# Import blocks (Terraform 1.5+) declaring the 9 existing AWS resources this lab
# brings under Terraform management: a VPC stack of 5, plus a security group and
# its 3 modern rule resources.
#
# Why these 9 and not more?
#   - NO S3 bucket: lab1/state-infra already manages it. You do not import a
#     resource that is already managed elsewhere -- that creates dual-management,
#     where two states each believe they own it.
#   - NO NAT gateway: nothing here needs one, and it bills by the hour.
#   - NO load balancer or auto scaling group: not part of the import lesson.
#
# Dependency order matters:
#   VPC -> subnet -> IGW -> route table -> route table association
#   security group -> its rules (the rules reference the SG ID)

# ---------------------------------------------------------------------------
# VPC stack (5 resources)
# ---------------------------------------------------------------------------

import {
  to = aws_vpc.custom-vpc
  id = var.vpc_id
}

import {
  to = aws_subnet.subnet-a
  id = var.subnet_id
}

import {
  to = aws_internet_gateway.igw
  id = var.internet_gateway_id
}

import {
  to = aws_route_table.public_rt
  id = var.route_table_id
}

# Compound ID format for route table associations:
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association#import
import {
  to = aws_route_table_association.public_subnet_a
  id = "${var.subnet_id}/${var.route_table_id}"
}

# ---------------------------------------------------------------------------
# Security group + 3 modern rules — the four blocks written in Lab 2, Step 8
# ---------------------------------------------------------------------------
# Order matters: the security group must import before its rules, because the
# rules reference the SG ID.

import {
  to = aws_security_group.allow-http-ssh
  id = var.security_group_id
}

import {
  to = aws_vpc_security_group_ingress_rule.allow-http-ipv4
  id = var.sg_rule_http_id
}

import {
  to = aws_vpc_security_group_ingress_rule.allow-ssh-ipv4
  id = var.sg_rule_ssh_id
}

import {
  to = aws_vpc_security_group_egress_rule.allow-all-outbound
  id = var.sg_rule_egress_id
}
