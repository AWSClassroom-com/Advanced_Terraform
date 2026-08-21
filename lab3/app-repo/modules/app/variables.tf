# modules/app/variables.tf
# Inputs to the shared application module.

variable "user_id" {
  description = "Your assigned AWS login ID (for example user07), the same value you used in Lab 1. Used to namespace every resource so 25 students can deploy in parallel without name collisions."
  type        = string

  validation {
    condition     = can(regex("^user[0-9]{2}$", var.user_id))
    error_message = "user_id must match 'userNN' with two digits - for example user07. Replace the userXX placeholder with your assigned AWS login ID, the same value you used in Lab 1."
  }
}

variable "environment" {
  description = "Environment name — staging or prod. Drives subnet CIDR and resource Name tags."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be \"staging\" or \"prod\"."
  }
}

variable "instance_count" {
  description = "Reserved for future scaling — currently a single EC2 instance is deployed regardless. Kept on the interface so the wrapper modules don't need to change when scaling is added."
  type        = number
  default     = 1
}
