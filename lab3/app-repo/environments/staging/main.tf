# environments/staging/main.tf — Staging environment
# Deployed automatically by Lab 3's CodePipeline. Every environment-specific
# value — the state bucket, its region, and your user_id — is injected by the
# pipeline at build time, so there is nothing to hand-edit in this file.
# Staging deploys to var.staging_region, a different region from prod.

terraform {
  required_version = ">= 1.10.0"

  # The pipeline supplies bucket and region at init time via
  # -backend-config; a backend block cannot read variables.
  backend "s3" {
    key          = "pipeline/staging/terraform.tfstate"
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
  region = var.staging_region

  default_tags {
    tags = {
      Student     = var.user_id
      Environment = "staging"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

variable "user_id" {
  description = "Your assigned AWS login ID. The pipeline injects this as TF_VAR_user_id, so there is nothing to edit here."
  type        = string
  default     = "userXX"
}

variable "staging_region" {
  description = "Where the staging environment deploys. Different from the primary region on purpose - promotion crosses regions."
  type        = string
  default     = "us-east-1"
}

# Main path: EC2 + Apache (matches Day 1-2 pattern).
# To switch to the serverless bonus module, change `source` to
# "../../modules/app-serverless" and re-push. The interface is identical
# so no other changes are required here.
module "app" {
  source      = "../../modules/app"
  user_id     = var.user_id
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
