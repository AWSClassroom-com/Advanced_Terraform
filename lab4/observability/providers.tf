# lab4-observability/providers.tf
#
# Same backend pattern as the other modules — bucket and region are passed
# at init time via `-backend-config="bucket=..." -backend-config="region=..."`
# so this file is portable across students and regions.

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    key          = "observability/terraform.tfstate"
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
  region = var.region
}
