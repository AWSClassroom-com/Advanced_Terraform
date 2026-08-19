# environments/staging/main.tf — Staging environment
# Deployed automatically by Lab 3's CodePipeline. Region is pinned to
# the staging region; backend bucket name is patched by the student
# before the first commit.

terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "userXX-terraform-state-SUFFIX" # replace before first commit
    key          = "pipeline/staging/terraform.tfstate"
    region       = "us-east-2" # staging region — adjust if your bucket lives elsewhere
    encrypt      = true
    use_lockfile = true # Terraform 1.10+ S3 native locking
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-2" # staging deploy region

  default_tags {
    tags = {
      Student     = "userXX" # replace before first commit
      Environment = "staging"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

# Main path: EC2 + Apache (matches Day 1-2 pattern).
# To switch to the serverless bonus module, change `source` to
# "../../modules/app-serverless" and re-push. The interface is identical
# so no other changes are required here.
module "app" {
  source      = "../../modules/app"
  student_id  = "userXX" # replace before first commit
  environment = "staging"
}

output "public_ip" {
  description = "Public IP of the staging web server (null when using the serverless module)."
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
