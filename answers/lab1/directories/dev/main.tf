# lab1-directories/dev/main.tf
#
# Dev environment composition. environment is HARDCODED to "dev" — there is
# no way to accidentally apply this directory to staging or prod, because
# you would have to physically `cd ../staging` first.

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07)."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07."
  }
}

variable "primary_region" {
  description = "The region you work in. This environment's resources are created here."
  type        = string
  default     = "us-east-2"
}

variable "bucket_region" {
  description = "Region the state bucket lives in. Passed through to the module's terraform_remote_state config."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = "S3 bucket holding networking state. Same bucket as your backend, but the variable is needed because the module's terraform_remote_state config can't reuse the backend block."
  type        = string
}

module "app" {
  source = "../modules/app"

  user_id           = var.user_id
  environment       = "dev" # Explicit — not from workspace
  state_bucket_name = var.state_bucket_name
  bucket_region     = var.bucket_region
}

output "app_config_parameter_name" {
  description = "SSM parameter path created by the dev environment."
  value       = module.app.app_config_parameter_name
}
