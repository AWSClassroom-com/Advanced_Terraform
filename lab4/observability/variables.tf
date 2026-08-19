# lab4-observability/variables.tf

variable "region" {
  description = "AWS region. NO default — set in terraform.tfvars to whatever your instructor assigned."
  type        = string
}

variable "account" {
  description = "Your IAM user account name (e.g. user01). Used to namespace the dashboard and resources. Same value as Day 1-2 var.account."
  type        = string
}

variable "state_bucket_name" {
  description = "Full name of the state bucket Lab 1 created (e.g., user01-terraform-state-ab12cd, from `terraform output state_bucket_name` in lab1/state-infra). The dashboard's S3 widgets read metrics for this bucket directly — backend blocks can't take variables, so this has to be passed in."
  type        = string
}
