# lab1-networking/variables.tf

variable "account" {
  description = "Your assigned IAM username (e.g., user01). Used to namespace and tag resources in the shared lab account."
  type        = string
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
