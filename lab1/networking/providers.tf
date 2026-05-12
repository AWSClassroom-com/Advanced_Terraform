# lab1-networking/providers.tf
#
# Backend stores the "networking" state at a fixed key (no workspace prefix).
# Application state in lab1-state-infra reads VPC outputs from this state via
# the terraform_remote_state data source — that's the cross-state dependency
# pattern Lab 1 Part C teaches.
#
# Students must edit the bucket value to match the bucket they created in
# Day 2 Lab 3 (or via Lab 1's setup). Terraform backend blocks cannot use
# variables — the bucket name has to be a literal string here.

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "tf-state-userxx-XXXXXXXX"     # REPLACE: your bucket from Day 2
    key          = "networking/terraform.tfstate" # No env:/ prefix — networking state is shared
    region       = "us-east-2"                    # change to your assigned region if not us-east-2
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
  region = "us-east-2" # change to your assigned region if not us-east-2

  default_tags {
    tags = {
      Course    = "Terraform Day 3"
      Lab       = "Lab 1 - Networking"
      ManagedBy = "terraform"
      Owner     = "networking-team"
    }
  }
}
