# demo/cloudtrail-audit/variables.tf

variable "class_prefix" {
  description = "Names the trail, its bucket, and the log group. The course name is fine; there is nothing per-cohort to maintain."
  type        = string
  default     = "advanced-terraform"
}

variable "primary_region" {
  description = "Region the trail runs in. Use the region the class deploys to, so S3 data events are recorded locally."
  type        = string
  default     = "us-east-2"
}

variable "multi_region" {
  description = "Set true to capture events from every region. Lab 3 deploys prod to us-west-2, so true is the useful setting for a full audit picture."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention. A class only needs a few days, and retention caps the storage bill."
  type        = number
  default     = 7
}
