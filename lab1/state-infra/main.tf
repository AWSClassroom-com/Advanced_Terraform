# main.tf
# State infrastructure: S3 bucket for state storage
#
# This is the "bootstrap" configuration. These resources are created with
# local state first, then we migrate to remote state in Part B.
#
# Note: Terraform now uses S3 native locking (use_lockfile = true) instead
# of DynamoDB, so we only need the S3 bucket.

# ---------------------------------------------------------------
# Random suffix to guarantee globally unique resource names.
# This prevents S3 bucket name collisions across class cohorts.
# ---------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ---------------------------------------------------------------
# S3 Bucket for Terraform State
# ---------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.student_id}-terraform-state-${random_string.suffix.result}"

  # In production, set this to true to prevent accidental deletion.
  # For this lab, we leave it false so you can clean up afterward.
  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.student_id}-terraform-state-${random_string.suffix.result}"
  }
}

# Enable versioning so every state change is preserved
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption (AES256) for all objects
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block ALL public access -- state files must never be public
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------
# Locking Demo: Slow resource to hold the lock for 30 seconds
# ---------------------------------------------------------------

resource "time_sleep" "locking_demo" {
  create_duration = "30s"

  triggers = {
    # Change this value to force recreation and trigger the delay
    demo_run = "run1"
  }
}

resource "aws_ssm_parameter" "lock_demo" {
  name        = "/${var.student_id}/lab1/lock-demo"
  description = "Parameter created after 30-second delay to demonstrate state locking"
  type        = "String"
  value       = "Lock demo completed at ${timestamp()}"

  depends_on = [time_sleep.locking_demo]

  tags = {
    Name = "${var.student_id}-lock-demo"
  }

  lifecycle {
    ignore_changes = [value]
  }
}
