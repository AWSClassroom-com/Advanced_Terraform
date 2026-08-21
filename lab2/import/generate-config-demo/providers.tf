# lab2/import/generate-config-demo/providers.tf
#
# LOCAL backend by design — this directory exists only to demonstrate
# `terraform plan -generate-config-out`. The demo never runs `terraform apply`,
# so it has no state worth keeping in S3. Using local state means students
# don't need to configure a backend just to see the generate-config behavior.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.primary_region
}
