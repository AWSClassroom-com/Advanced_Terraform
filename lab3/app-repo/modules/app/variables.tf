# modules/app/variables.tf
# Inputs to the shared application module.

variable "student_id" {
  description = "Student identifier (e.g. student07). Used to namespace every resource so 25 students can deploy in parallel without name collisions."
  type        = string
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
