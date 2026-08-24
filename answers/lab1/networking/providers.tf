# lab1-networking/providers.tf
#
# Backend stores the "networking" state at a fixed key (no workspace prefix).
# Application state in lab1-state-infra reads VPC outputs from this state via
# the terraform_remote_state data source — that's the cross-state dependency
# pattern Lab 1 Part C teaches.
#
# A backend block cannot read variables, so the bucket and its region are
# supplied at init time instead of being written here:
#   terraform init \
#     -backend-config="bucket=<state_bucket_name from lab1/state-infra>" \
#     -backend-config="region=<your bucket_region>"

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    key          = "networking/terraform.tfstate" # No env:/ prefix — networking state is shared
    encrypt      = true
    use_lockfile = true # Terraform 1.10+ S3 native locking
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      User      = var.user_id
      Course    = "Terraform Day 3"
      Lab       = "Lab 1 - Networking"
      ManagedBy = "terraform"
      Owner     = "networking-team"
    }
  }
}
