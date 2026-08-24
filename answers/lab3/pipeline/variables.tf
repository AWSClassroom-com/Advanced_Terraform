# variables.tf
# Input variables for Lab 3 pipeline infrastructure

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07) — the same value you used in Lab 1"
  type        = string

  validation {
    # Must match Lab 1's `^user[0-9]{2}$` exactly. Any other ID would differ
    # from the one Lab 1 forced, which silently breaks Lab 4 -- its dashboard
    # widgets key off this same value and would all read "No data".
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07. Use the same value you used in Lab 1."
  }
}

variable "primary_region" {
  description = "The region you work in. The pipeline, its CodeBuild projects, and the CodeCommit repo are created here. Staging and prod deploy elsewhere - see the environment wrappers in app-repo."
  type        = string
  default     = "us-east-2"
}

variable "bucket_region" {
  description = "Region the state bucket lives in. Passed to each build as BUCKET_REGION so the environment wrappers can init their backends without hardcoding it."
  type        = string
  default     = "us-east-2"
}

# NOTE: state_bucket_name is used by the pipeline's IAM policies and the
# environment wrappers. The BACKEND's bucket is passed separately at init
# time via -backend-config, because a backend block cannot read variables.

variable "state_bucket_name" {
  description = "S3 bucket name from Lab 1 output (e.g., user01-terraform-state-abc123)"
  type        = string

  validation {
    condition     = !can(regex("(SUFFIX|userXX)", var.state_bucket_name))
    error_message = "Replace placeholder with your actual bucket name from Lab 1 output (terraform output state_bucket_name)."
  }
}
