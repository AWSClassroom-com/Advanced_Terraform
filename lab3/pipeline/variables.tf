# variables.tf
# Input variables for Lab 3 pipeline infrastructure

variable "student_id" {
  description = "Your student ID (e.g., user01) — same value as Lab 1"
  type        = string

  validation {
    # Must match Lab 1's `^user[0-9]{2}$` exactly. Any other ID would differ
    # from the one Lab 1 forced, which silently breaks Lab 4 -- its dashboard
    # widgets key off this same value and would all read "No data".
    condition     = can(regex("^user[0-9]{2}$", var.student_id))
    error_message = "student_id must match 'userNN' with two digits - for example user07. Use the same value you used in Lab 1."
  }
}

# NOTE: This variable is for documentation/reference only.
# The backend block in providers.tf cannot use variables - you must
# manually copy this value into the backend block after Lab 1 is deployed.

variable "state_bucket_name" {
  description = "S3 bucket name from Lab 1 output (e.g., user01-terraform-state-abc123)"
  type        = string

  validation {
    condition     = !can(regex("(SUFFIX|userXX)", var.state_bucket_name))
    error_message = "Replace placeholder with your actual bucket name from Lab 1 output (terraform output state_bucket_name)."
  }
}
