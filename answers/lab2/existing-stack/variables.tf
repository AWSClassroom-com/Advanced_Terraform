# lab2/existing-stack/variables.tf
#
# Resource names here must match what lab2/import/ expects to import.

variable "primary_region" {
  description = "AWS region. NO default — set it in terraform.tfvars to the region your instructor assigned."
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
  description = "CIDR block for the VPC."
  type        = string
  default     = "192.168.0.0/20"
}

variable "public_subnet_a_name" {
  description = "Name suffix for the public subnet."
  type        = string
  default     = "public-subnet-a"
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "192.168.0.0/24"
}

variable "route_table_name" {
  description = "Name suffix for the public route table."
  type        = string
  default     = "public-route-table"
}
