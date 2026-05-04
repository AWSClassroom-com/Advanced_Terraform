# variables.tf
# Input variables for the shared application module

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "student_id" {
  description = "Student identifier for resource namespacing"
  type        = string
}

variable "instance_count" {
  description = "Number of application instances (stored as config)"
  type        = number
  default     = 2
}
