# providers.tf
# AWS Provider configuration with S3 backend for remote state

terraform {
  required_version = ">= 1.10.0"

  # STEP 12: Remote state backend
  # -----------------------------------------------------------------
  # After Step 11 creates the bucket, uncomment the block below and replace the
  # placeholder value with your actual bucket name from `terraform output`.
  # Then run `terraform init` to migrate state.
  #
  # Example: If your output shows:
  #   state_bucket_name = "user01-terraform-state-abc123"
  #
  # Then your backend block should be:
  #   bucket = "user01-terraform-state-abc123"
  # -----------------------------------------------------------------
  # backend "s3" {
  #   key          = "lab1-app/terraform.tfstate"
  #   encrypt      = true
  #   use_lockfile = true # S3 native locking - no DynamoDB table needed
  # }
  #
  # Note there is no bucket or region here. A backend block cannot read
  # variables, so those two values are passed at init time instead:
  #   terraform init -migrate-state \
  #     -backend-config="bucket=<your state bucket>" \
  #     -backend-config="region=<your bucket_region>"
  # This is the same -backend-config pattern you used on Day 1-2.

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
  region = var.primary_region

  default_tags {
    tags = {
      User        = var.user_id
      Project     = "terraform-state-infra"
      Environment = "management"
      ManagedBy   = "Terraform"
      Lab         = "day3-lab1"
    }
  }
}
