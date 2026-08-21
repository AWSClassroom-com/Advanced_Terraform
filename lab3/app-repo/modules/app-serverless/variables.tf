# modules/app-serverless/variables.tf
# Same interface as modules/app/variables.tf so the wrappers can swap
# modules by changing only the `source = ...` line.

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07), the same value you used in Lab 1. Used to namespace Lambda functions, IAM roles, and API Gateway APIs."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07. Replace the userXX placeholder with your assigned AWS login ID, the same value you used in Lab 1."
  }
}

variable "environment" {
  description = "Environment name — staging or prod. Pushed to the Lambda runtime as the ENVIRONMENT env var."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be \"staging\" or \"prod\"."
  }
}

variable "instance_count" {
  description = "Unused for serverless — kept on the interface so wrappers don't need to change when swapping back."
  type        = number
  default     = 1
}
