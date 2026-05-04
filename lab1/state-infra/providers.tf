# providers.tf
# AWS Provider configuration with S3 backend for remote state

terraform {
  required_version = ">= 1.5.0"

  # PART B: Remote state backend
  # -----------------------------------------------------------------
  # After Part A completes, uncomment the block below and replace the
  # placeholder value with your actual bucket name from `terraform output`.
  # Then run `terraform init` to migrate state.
  #
  # Example: If your output shows:
  #   state_bucket_name = "student01-terraform-state-abc123"
  #
  # Then your backend block should be:
  #   bucket = "student01-terraform-state-abc123"
  # -----------------------------------------------------------------
  # backend "s3" {
  #   bucket       = "studentXX-terraform-state-SUFFIX"  # <- Replace with state_bucket_name
  #   key          = "platform/state-infra/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true  # Uses S3 native locking instead of DynamoDB
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Random provider for unique resource naming
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    # Time provider for the locking demonstration
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Student     = "studentXX"
      Project     = "terraform-state-infra"
      Environment = "management"
      ManagedBy   = "Terraform"
      Lab         = "day3-lab1"
    }
  }
}
