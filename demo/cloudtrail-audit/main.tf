# demo/cloudtrail-audit/main.tf
#
# ONE trail for the whole class. The instructor applies this once, before
# Lab 1 starts; students never run it. It has to be running before the labs
# begin, not before Lab 4 -- a trail only records what happens after it
# exists, and Lab 4 Task 2 queries the Lab 1-3 activity.
#
# Why one shared trail and not one per student: CloudTrail allows a maximum
# of 5 trails per Region and that quota cannot be increased. A class of 15
# would fail on the sixth apply.
#
# The trail records management events plus S3 data events on every bucket in
# the account, and delivers both to a CloudWatch log group. Data events are
# what Lab 4 Task 2 needs: object-level calls such as PutObject never appear
# in CloudTrail event history, so without a trail there is no way to see the
# writes Terraform makes to a state file.
#
# Students share the log group read-only and filter to their own bucket, so
# nobody's query interferes with anyone else's.

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ---------------------------------------------------------------
# Where the trail writes its log files
# ---------------------------------------------------------------

resource "aws_s3_bucket" "trail" {
  bucket        = "${var.class_prefix}-audit-trail-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "${var.class_prefix}-audit-trail"
    Purpose = "CloudTrail log destination for the class"
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

# CloudTrail checks the bucket ACL before its first write, then puts objects
# under AWSLogs/<account-id>/. Both statements are required or CreateTrail
# fails validation.
resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------
# Where students read the events
# ---------------------------------------------------------------

resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.class_prefix}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.class_prefix}-cloudtrail"
  }
}

resource "aws_iam_role" "trail_to_logs" {
  name = "${var.class_prefix}-cloudtrail-to-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "trail_to_logs" {
  name = "write-to-log-group"
  role = aws_iam_role.trail_to_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
    }]
  })
}

# ---------------------------------------------------------------
# The trail
# ---------------------------------------------------------------

resource "aws_cloudtrail" "class" {
  name           = "${var.class_prefix}-audit-trail"
  s3_bucket_name = aws_s3_bucket.trail.id

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.trail_to_logs.arn

  include_global_service_events = true
  is_multi_region_trail         = var.multi_region

  # `arn:aws:s3` with no bucket selects every bucket in the account, present
  # and future, so a student's Lab 1 bucket is covered without this config
  # knowing its name. Selecting all buckets also sidesteps the 250
  # data-resource limit that applies when buckets are listed individually.
  advanced_event_selector {
    name = "S3 object events on every bucket"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    # Without this the trail records its own log deliveries. Every file
    # CloudTrail writes here is a PutObject on an S3 bucket, which matches the
    # selector, which produces another event, which produces another file. It
    # bills per event and buries real activity in student queries.
    field_selector {
      field           = "resources.ARN"
      not_starts_with = [aws_s3_bucket.trail.arn]
    }
  }

  advanced_event_selector {
    name = "All management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  depends_on = [aws_s3_bucket_policy.trail]

  tags = {
    Name = "${var.class_prefix}-audit-trail"
  }
}
