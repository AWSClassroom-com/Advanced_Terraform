# variables.tf
# Input variables for Lab 1 state infrastructure

variable "student_id" {
  description = "Your assigned student ID (e.g., student01)"
  type        = string

  validation {
    condition     = can(regex("^student[0-9]{2}$", var.student_id))
    error_message = "Student ID must match the pattern 'studentXX' where XX is a two-digit number."
  }
}
