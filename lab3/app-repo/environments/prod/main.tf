# environments/prod/main.tf — Production environment
# Deployed automatically by Lab 3's CodePipeline AFTER the staging stage
# has applied AND the human approver has clicked through the gate.
# Production deploys to a DIFFERENT region from staging — this is the
# whole point of the multi-region story in Chapter 3. The state bucket, its
# region, and your user_id are injected by the pipeline at build time.

terraform {
  required_version = ">= 1.10.0"

  # The pipeline supplies bucket and region at init time via
  # -backend-config; a backend block cannot read variables.
  backend "s3" {
    key          = "pipeline/prod/terraform.tfstate"
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
  region = var.prod_region

  default_tags {
    tags = {
      User        = var.user_id
      Environment = "prod"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

variable "user_id" {
  description = "Your assigned AWS login ID. The pipeline injects this as TF_VAR_user_id, so there is nothing to edit here."
  type        = string
  default     = "userXX"
}

variable "prod_region" {
  description = "Where production deploys. A different region again, so a regional failure cannot take both environments out."
  type        = string
  default     = "us-west-2"
}

module "app" {
  source      = "../../modules/app"
  user_id     = var.user_id
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
