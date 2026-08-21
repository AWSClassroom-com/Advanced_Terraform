# lab2-day1-vpc-lean/providers.tf
#
# LOCAL state by design — this stack simulates "console-built / Day 1-2-built"
# infrastructure that lives outside Terraform's managed remote state. The whole
# point of Lab 2 is to import these resources INTO remote state.
#
# Day 1-2 pattern: providers configured here, no backend block.

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
