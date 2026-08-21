# lab2-day1-vpc-lean/variables.tf
#
# Identical to aws/vpc/variables.tf from the Day 1-2 repo so resource names
# match exactly when imported into lab2-import/.

variable "primary_region" {
  description = "AWS region. NO default — set in terraform.tfvars to whatever your instructor assigned (matches Day 1-2 convention)."
  type        = string
}

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07). Used to prefix resource names."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07. Replace the placeholder from terraform.tfvars.example with your assigned AWS login ID."
  }
}

variable "vpc_name" {
  description = "Name suffix for the VPC. Combined with user_id to form the full VPC Name tag (user_id-vpc_name)."
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
