# lab1-directories/modules/app/variables.tf
#
# Inputs for the shared "app" module that both dev/ and staging/ use.
# Note: environment is EXPLICIT (passed by the caller), not from terraform.workspace.
# That's the whole point of the directory pattern — no implicit workspace lookup.

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07)."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07. Replace the placeholder from terraform.tfvars.example with your assigned AWS login ID."
  }
}

variable "bucket_region" {
  description = "Region the state bucket lives in. Read by the terraform_remote_state config below - a data source CAN take a variable, unlike a backend block."
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev / staging / prod). Passed explicitly by the caller — not derived from terraform.workspace."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket holding the networking state file. Used to construct the terraform_remote_state config. Must be the actual bucket name (no variable interpolation in backend blocks anywhere downstream)."
  type        = string
}
