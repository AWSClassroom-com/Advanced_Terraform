# variables.tf
# Input variables for Lab 1 state infrastructure

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07). Names the S3 state bucket and every resource this lab creates."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07."
  }
}

variable "primary_region" {
  description = "The region you work in: this lab's resources and your state bucket are created here. Change it here, not in the code."
  type        = string
  default     = "us-east-2"
}

variable "bucket_region" {
  description = "Region the S3 state bucket lives in. Separate from primary_region because a backend's region is the BUCKET's region, independent of where resources deploy. Read by the cross-state data source in main.tf; the backend itself takes it from -backend-config at init time."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = "S3 bucket containing the lab1/networking remote state. Set after lab1/networking has been deployed once and you have captured the state_bucket_name output. Pass as -var state_bucket_name=<name> or set in terraform.tfvars."
  type        = string
  default     = ""
}

# ============================================================================
# Workspace-aware configuration
# ============================================================================
# This locals block illustrates how `terraform.workspace` lets one
# configuration serve multiple environments. Switch workspaces and the
# values change automatically. Subsequent labs and modules reference
# `local.config.instance_type`, `local.config.min_size`, etc.
# ----------------------------------------------------------------------------

locals {
  environment_config = {
    dev = {
      instance_type = "t3.micro"
      min_size      = 1
      max_size      = 2
    }
    staging = {
      instance_type = "t3.small"
      min_size      = 2
      max_size      = 4
    }
    prod = {
      instance_type = "t3.medium"
      min_size      = 3
      max_size      = 10
    }
  }

  # Falls back to dev if workspace isn't one of the three above (so plans
  # succeed before Step 13's workspace_guard.tf is in place).
  config = lookup(local.environment_config, terraform.workspace, local.environment_config.dev)
}
