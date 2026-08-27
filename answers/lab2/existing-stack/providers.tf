# lab2/existing-stack/providers.tf
#
# LOCAL state by design — this stack plays the role of infrastructure that
# was built outside Terraform's managed remote state. The whole
# point of Lab 2 is to import these resources INTO remote state.
#
# Providers configured here, no backend block — nothing remote owns this state.

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
