# lab1-directories/staging/main.tf
#
# Staging composition. Same module as dev/, just instantiated with
# environment = "staging". The directory layout makes "what env am I in?"
# physically obvious.

variable "account" {
  description = "Your assigned IAM username (e.g., user01)."
  type        = string
}

variable "state_bucket_name" {
  description = "S3 bucket holding networking state (same bucket as the backend)."
  type        = string
}

module "app" {
  source = "../modules/app"

  account        = var.account
  environment       = "staging"   # Explicit — not from workspace
  state_bucket_name = var.state_bucket_name
}

output "app_config_parameter_name" {
  description = "SSM parameter path created by the staging environment."
  value       = module.app.app_config_parameter_name
}
