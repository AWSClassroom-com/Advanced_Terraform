# lab2-import/imports.tf
#
# Import blocks (Terraform 1.5+) declaring 9 existing AWS resources to bring
# under Terraform management. Resource addresses match Day 1-2 Lab 3 Task 2
# (VPC stack) and Task 3 (allow-http-ssh security group with modern rules) —
# pre-Lab 4 refactor (single subnet, no for_each).
#
# Why these 9 and not more?
#   - NO S3 bucket: Day 1-2 Lab 3 already manages it under `module.s3_bucket`.
#     You don't import resources that are already managed elsewhere — that
#     creates dual-state. You also generally don't experiment with state
#     buckets in import labs because of recursive-destroy risk.
#   - NO NAT gateway: cost concern (~$1/day per student).
#   - NO ALB / ALB SG: Lab 5 territory; not needed for the import lesson.
#   - NO for_each subnets: keeps the resource-address concepts clean.
#     Students learned for_each in Lab 4; they don't need to re-learn it
#     while focusing on import semantics.
#
# Dependency order matters (facts_extracted.md §6):
#   VPC -> subnet -> IGW -> route table -> route table association

# ---------------------------------------------------------------------------
# VPC stack (5 resources, lifted from Lab 3 Task 2 / aws/vpc/custom-vpc.tf)
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
# Security group + 3 modern rules (Lab 3 Task 3 / aws/security-group/)
# Note: Day 1-2 uses the modern aws_vpc_security_group_*_rule resources, NOT
# inline ingress {} / egress {} blocks. This is the AWS-recommended pattern.
# ---------------------------------------------------------------------------

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
