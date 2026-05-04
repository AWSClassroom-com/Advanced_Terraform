# environments/prod/main.tf - Production environment
# Deployed to us-west-2 via the pipeline (geographic separation from staging)

terraform {
  required_version = ">= 1.5.0"

  # Use the actual bucket name from your Lab 1 `terraform output`
  backend "s3" {
    bucket       = "studentXX-terraform-state-SUFFIX"
    key          = "pipeline/prod/terraform.tfstate"
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
  region = "us-west-2"

  default_tags {
    tags = {
      Student     = "studentXX"
      Environment = "production"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

module "app" {
  source         = "../../modules/app"
  environment    = "prod"
  student_id     = "studentXX"
  instance_count = 3
}

output "config_parameter" {
  description = "Production config parameter name"
  value       = module.app.config_parameter_name
}
