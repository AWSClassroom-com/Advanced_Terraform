# lab2-import/providers.tf
#
# Lab 2 uses the SAME state bucket Lab 1 created (lab1/state-infra's
# `terraform output state_bucket_name`) but a SEPARATE state path under
# `imported/`. Workspaces (dev/staging/prod) follow Lab 1's pattern — the
# import happens in the dev workspace.
#
# Backend pattern: bucket and region are passed at init time via
# `-backend-config="bucket=..."` and `-backend-config="region=..."` rather
# than hardcoded here. We follow that convention.

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    key          = "imported/terraform.tfstate" # Workspace prefix env:/dev/ added automatically
    encrypt      = true
    use_lockfile = true # Terraform 1.10+ S3 native locking — Day 3 NEW material
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}
