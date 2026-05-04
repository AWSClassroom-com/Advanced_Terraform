# environments/staging/main.tf - Staging environment
# Deployed to us-east-1 via the pipeline

terraform {
  required_version = ">= 1.5.0"

  # Use the actual bucket name from your Lab 1 `terraform output`
  backend "s3" {
    bucket       = "studentXX-terraform-state-SUFFIX"
    key          = "pipeline/staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Uses S3 native locking instead of DynamoDB
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Student     = "studentXX"
      Environment = "staging"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

module "app" {
  source = "../../modules/app"
  environment = "staging"
  student_id     =    "studentXX"
  instance_count = 2
}

output "config_parameter" {
  description = "Staging config parameter name"
  value       = module.app.config_parameter_name
}
