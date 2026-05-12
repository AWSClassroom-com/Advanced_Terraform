# lab1-directories/staging/providers.tf
#
# Staging environment backend. Distinct state path from dev/. Same bucket
# (you only need one state bucket per account) but a different key.

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "tf-state-userxx-XXXXXXXX"              # REPLACE: your bucket
    key          = "directories/staging/terraform.tfstate" # Path includes env name
    region       = "us-east-2"                             # change to your assigned region if not us-east-2
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
  region = "us-east-2" # change to your assigned region if not us-east-2
}
