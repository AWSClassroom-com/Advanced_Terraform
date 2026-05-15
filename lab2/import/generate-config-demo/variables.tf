# lab2/import/generate-config-demo/variables.tf
#
# Subset of the parent lab2/import/ variables — only the 8 resource IDs the
# imports.tf in this dir actually references. The parent's vpc_cidr /
# public_subnet_cidr are intentionally not declared here because the demo
# never runs `terraform apply`; it only does `terraform plan -generate-config-out`,
# which doesn't need CIDR values.

variable "region" {
  description = "AWS region. No default — set in terraform.tfvars to whatever your instructor assigned."
  type        = string
}

variable "account" {
  description = "Your IAM user account name (e.g. user01). Used to prefix resource names. Same value as Day 1-2 var.account."
  type        = string
}

# ---------------------------------------------------------------------------
# Resource IDs students paste in from Day 1-2 (or from `lab2-day1-vpc-lean/`).
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the existing VPC to import. Get from Day 1-2 deployment or `terraform output vpc_id` in lab2-day1-vpc-lean/."
  type        = string
}

variable "subnet_id" {
  description = "ID of the existing public subnet to import."
  type        = string
}

variable "internet_gateway_id" {
  description = "ID of the existing internet gateway to import."
  type        = string
}

variable "route_table_id" {
  description = "ID of the existing public route table to import."
  type        = string
}

# Note: aws_route_table_association uses a COMPOUND ID for import:
# `<subnet_id>/<route_table_id>`. We construct it from the two vars above.

variable "security_group_id" {
  description = "ID of the existing allow-http-ssh security group (e.g. sg-0abcdef...)."
  type        = string
}

variable "sg_rule_http_id" {
  description = "ID of the HTTP ingress rule (sgr-...). Get from `aws ec2 describe-security-group-rules` or from outputs of lab2-day1-vpc-lean/."
  type        = string
}

variable "sg_rule_ssh_id" {
  description = "ID of the SSH ingress rule (sgr-...)."
  type        = string
}

variable "sg_rule_egress_id" {
  description = "ID of the egress all-outbound rule (sgr-...)."
  type        = string
}

