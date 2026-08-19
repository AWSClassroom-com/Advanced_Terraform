# environments/prod/main.tf — Production environment
# Deployed automatically by Lab 3's CodePipeline AFTER the staging stage
# has applied AND the human approver has clicked through the gate.
# Production deploys to a DIFFERENT region from staging — this is the
# whole point of the multi-region story in Module 3.

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "userXX-terraform-state-SUFFIX" # replace before first commit
    key          = "pipeline/prod/terraform.tfstate"
    region       = "us-east-2" # bucket region — bucket itself lives in staging region
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
  region = "us-west-2" # prod deploy region — different from staging

  default_tags {
    tags = {
      Student     = "userXX" # replace before first commit
      Environment = "prod"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

module "app" {
  source      = "../../modules/app"
  student_id  = "userXX" # replace before first commit
  environment = "prod"
}

output "public_ip" {
  description = "Public IP of the prod web server (null when using the serverless module)."
  value       = module.app.public_ip
}

output "api_url" {
  description = "API Gateway URL — populated only when using the serverless module."
  value       = module.app.api_url
}

output "instance_id" {
  description = "EC2 instance ID or Lambda function name, depending on which module is in use."
  value       = module.app.instance_id
}

output "vpc_id" {
  description = "VPC ID for this environment (null when using the serverless module)."
  value       = module.app.vpc_id
}
