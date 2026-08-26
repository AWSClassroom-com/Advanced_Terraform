# variables.tf
# Input variables for Lab 3 pipeline infrastructure

variable "terraform_version" {
  description = <<-EOT
    Terraform version the pipeline installs. Every CodeBuild container is thrown away
    at the end of a build, so each of the five projects installs Terraform from scratch
    on every run. Downloading the pinned binary takes about a second; installing it from
    the HashiCorp yum repo took about ninety, and gave whatever version was latest that
    morning - so a pipeline could change Terraform under a running class.
  EOT
  type        = string
  default     = "1.15.9"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.terraform_version))
    error_message = "terraform_version must be an exact version such as 1.15.9, not a constraint."
  }
}

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
