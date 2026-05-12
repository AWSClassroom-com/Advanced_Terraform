# lab2-day1-vpc-lean/variables.tf
#
# Identical to aws/vpc/variables.tf from the Day 1-2 repo so resource names
# match exactly when imported into lab2-import/.

variable "region" {
  description = "AWS region. NO default — set in terraform.tfvars to whatever your instructor assigned (matches Day 1-2 convention)."
  type        = string
}

variable "account" {
  description = "Your IAM user account name used to log in to AWS (e.g. user01). Used to prefix resource names. Same value as Day 1-2 var.account."
  type        = string
}

variable "vpc_name" {
  description = "Name suffix for the VPC. Combined with the account variable to form the full VPC Name tag (account-vpc_name)."
  type        = string
  default     = "vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Day 1-2 default."
  type        = string
  default     = "192.168.0.0/20"
}

variable "public_subnet_a_name" {
  description = "Name suffix for the public subnet."
  type        = string
  default     = "public-subnet-a"
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for the public subnet. Day 1-2 default."
  type        = string
  default     = "192.168.0.0/24"
}

variable "route_table_name" {
  description = "Name suffix for the public route table."
  type        = string
  default     = "public-route-table"
}
