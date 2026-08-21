# demo/cloudtrail-audit/providers.tf
#
# Local state on purpose. The instructor applies this once per cohort, before
# the class starts, so there is no shared state to coordinate and no
# chicken-and-egg with Lab 1's bucket.

terraform {
  required_version = ">= 1.10.0"

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
  region = var.region

  default_tags {
    tags = {
      Purpose   = "Classroom audit trail"
      ManagedBy = "Terraform"
    }
  }
}
