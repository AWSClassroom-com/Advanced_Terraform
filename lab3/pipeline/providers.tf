# providers.tf - Provider configuration and S3 backend

terraform {
  required_version = ">= 1.5.0"

  # Bucket and region are supplied at init time - a backend block cannot read
  # variables:
  #   terraform init -backend-config="bucket=<your state bucket from Lab 1>" \
  #                  -backend-config="region=<your bucket_region>"
  backend "s3" {
    key          = "pipeline/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # Uses S3 native locking instead of DynamoDB
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Student   = var.user_id
      Purpose   = "Terraform Pipeline"
      ManagedBy = "Terraform"
    }
  }
}
