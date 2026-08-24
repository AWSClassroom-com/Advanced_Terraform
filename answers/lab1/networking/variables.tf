# lab1-networking/variables.tf

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07). Used to namespace and tag resources in the shared lab account."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07. Replace the placeholder from terraform.tfvars.example with your assigned AWS login ID."
  }
}

variable "primary_region" {
  description = "The region you work in. This VPC is created here."
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the shared networking VPC. Must not overlap with other students' VPCs in the lab account."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet inside the networking VPC."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "AZ for the public subnet. us-east-2a is the lab default."
  type        = string
  default     = "us-east-2a"
}
