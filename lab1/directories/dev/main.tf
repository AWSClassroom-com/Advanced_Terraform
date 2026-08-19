# lab1-directories/dev/main.tf
#
# Dev environment composition. environment is HARDCODED to "dev" — there is
# no way to accidentally apply this directory to staging or prod, because
# you would have to physically `cd ../staging` first.

variable "account" {
  description = "Your assigned IAM username (e.g., user01)."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.account))
    error_message = "account must match 'userNN' with two digits - for example user07. Replace the placeholder from terraform.tfvars.example with your assigned IAM username."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket holding networking state. Same bucket as your backend, but the variable is needed because the module's terraform_remote_state config can't reuse the backend block."
  type        = string
}

module "app" {
  source = "../modules/app"

  account           = var.account
  environment       = "dev" # Explicit — not from workspace
  state_bucket_name = var.state_bucket_name
}

output "app_config_parameter_name" {
  description = "SSM parameter path created by the dev environment."
  value       = module.app.app_config_parameter_name
}
