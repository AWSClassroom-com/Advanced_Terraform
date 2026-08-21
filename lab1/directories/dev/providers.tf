# lab1-directories/dev/providers.tf
#
# Each environment directory has its own backend block pointing at a
# distinct state path. Notice: NO `env:/` prefix and NO workspace switching —
# the directory IS the environment.

terraform {
  required_version = ">= 1.10.0"

  # Bucket and region are supplied at init time - a backend block cannot read
  # variables:
  #   terraform init -backend-config="bucket=<your state bucket>" \
  #                  -backend-config="region=<your bucket_region>"
  backend "s3" {
    key          = "directories/dev/terraform.tfstate" # Path includes env name
    encrypt      = true
    use_lockfile = true
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
      User = var.user_id
      Lab  = "Lab 1 - directories"
    }
  }
}
