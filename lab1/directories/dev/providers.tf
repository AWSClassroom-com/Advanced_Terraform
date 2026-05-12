# lab1-directories/dev/providers.tf
#
# Each environment directory has its own backend block pointing at a
# distinct state path. Notice: NO `env:/` prefix and NO workspace switching —
# the directory IS the environment.

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "tf-state-userxx-XXXXXXXX"          # REPLACE: your bucket from Day 2
    key          = "directories/dev/terraform.tfstate" # Path includes env name
    region       = "us-east-2"                         # change to your assigned region if not us-east-2
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
