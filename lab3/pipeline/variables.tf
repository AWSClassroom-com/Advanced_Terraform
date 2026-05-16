# variables.tf
# Input variables for Lab 3 pipeline infrastructure

variable "student_id" {
  description = "Your student ID (e.g., student01)"
  type        = string

  validation {
    # Accepts both Day 3 Lab 1's convention (`userNN`) and the prior `studentNN`
    # convention. Labs in this course share identity-driven naming, so this
    # regex must match Lab 1's `^user[0-9]{2}$` validator.
    condition     = can(regex("^(user|student)[0-9]{2}$", var.student_id))
    error_message = "Student ID must match 'userXX' or 'studentXX' where XX is a two-digit number (e.g., user01 or student01)."
  }
}

# NOTE: This variable is for documentation/reference only.
# The backend block in providers.tf cannot use variables - you must
# manually copy this value into the backend block after Lab 1 is deployed.

variable "state_bucket_name" {
  description = "S3 bucket name from Lab 1 output (e.g., student01-terraform-state-abc123)"
  type        = string

  validation {
    condition     = !can(regex("(SUFFIX|studentXX)", var.state_bucket_name))
    error_message = "Replace placeholder with your actual bucket name from Lab 1 output (terraform output state_bucket_name)."
  }
}
