# lab4-observability/dashboard.tf  (LabForge patched version 2026-05-03)
#
# Drop-in replacement for the original dashboard.tf in the
# terraform-sample-app-pipeline repo. Two changes vs. the original:
#
#   1. S3 widget now uses var.state_bucket_name (which already exists in
#      variables.tf) instead of the hard-coded "${var.account}-terraform-state"
#      pattern. This makes the widget actually populate when the bucket has
#      a random suffix (which Lab 1's bucket does).
#
#   2. The "DynamoDB Lock Operations" widget is replaced with an "S3 Lockfile
#      PutObject" widget. Lab 1 uses Terraform 1.10+ S3 native locking
#      (use_lockfile = true) — there is no DynamoDB table to monitor.
#      Lockfile activity now shows up as PutObject calls on the state bucket
#      with a key suffix of `.tflock`.
#
# Everything else (CodeBuild widgets, CodePipeline widgets, quick links,
# audit query reference) is unchanged from the original.

resource "aws_cloudwatch_dashboard" "terraform_ops" {
  dashboard_name = "${var.account}-terraform-operations"

  dashboard_body = jsonencode({
    widgets = [
      # ---------------------------------------------------------------
      # Header
      # ---------------------------------------------------------------
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Terraform Operations Dashboard — ${var.account}\n**Account:** **Region:** us-east-2 | **State bucket:** `${var.state_bucket_name}`\n\nMonitors CI/CD pipeline health, state operations, and provides audit query references."
        }
      },

      # ---------------------------------------------------------------
      # Row 1: CI/CD Metrics
      # ---------------------------------------------------------------
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CodeBuild", "Duration", "ProjectName", "${var.account}-terraform-validate"],
            ["...", "${var.account}-terraform-plan-staging"],
            ["...", "${var.account}-terraform-apply-staging"],
            ["...", "${var.account}-terraform-plan-prod"],
            ["...", "${var.account}-terraform-apply-prod"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "CodeBuild Duration (seconds)"
          period  = 300
          stat    = "Average"
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", "${var.account}-terraform-apply-staging"],
            [".", "FailedBuilds", ".", "."],
            [".", "SucceededBuilds", ".", "${var.account}-terraform-apply-prod"],
            [".", "FailedBuilds", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "Build Success vs. Failure (Apply stages)"
          period  = 3600
          stat    = "Sum"
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 8
        height = 4
        properties = {
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionSucceeded", "PipelineName", "${var.account}-terraform-pipeline"]
          ]
          view   = "singleValue"
          region = "us-east-2" # change to your assigned region if not us-east-2
          title  = "Pipeline Successes"
          period = 86400
          stat   = "Sum"
        }
      },

      {
        type   = "metric"
        x      = 8
        y      = 8
        width  = 8
        height = 4
        properties = {
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionFailed", "PipelineName", "${var.account}-terraform-pipeline"]
          ]
          view   = "singleValue"
          region = "us-east-2" # change to your assigned region if not us-east-2
          title  = "Pipeline Failures"
          period = 86400
          stat   = "Sum"
        }
      },

      {
        type   = "metric"
        x      = 16
        y      = 8
        width  = 8
        height = 4
        properties = {
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionSucceeded", "PipelineName", "${var.account}-terraform-pipeline", { stat = "Sum" }],
            [".", "PipelineExecutionFailed", ".", ".", { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = "us-east-2"
          title   = "Pipeline Executions Over Time"
          period  = 3600
        }
      },

      # ---------------------------------------------------------------
      # Row 2: State & Infrastructure Operations
      # ---------------------------------------------------------------
      #
      # NOTE (LabForge patch): BucketName is var.state_bucket_name (the actual
      # bucket name with random suffix), NOT a constructed string.
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "GetRequests", "BucketName", var.state_bucket_name, "FilterId", "EntireBucket"],
            [".", "PutRequests", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "State Bucket Operations (Get = plan, Put = apply)"
          period  = 300
          stat    = "Sum"
        }
      },

      # PATCHED: was DynamoDB lock; now S3 lockfile PutObject activity.
      # Requires the bucket to have a request metrics filter on prefix .tflock —
      # see Appendix A of Lab 4 for the patch to lab1-state-infra/main.tf.
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "PutRequests", "BucketName", var.state_bucket_name, "FilterId", "lockfile-activity"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "State Lockfile Activity (S3 native locking — Terraform 1.10+)"
          period  = 300
          stat    = "Sum"
        }
      },

      # ---------------------------------------------------------------
      # Row 3: Reference Panels
      # ---------------------------------------------------------------
      {
        type   = "text"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          markdown = <<-EOT
            ## Quick Links

            - [CodePipeline → ${var.account}-terraform-pipeline](https://us-east-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/${var.account}-terraform-pipeline/view)
            - [CodeBuild Projects](https://us-east-2.console.aws.amazon.com/codesuite/codebuild/projects)
            - [CloudTrail Event History](https://us-east-2.console.aws.amazon.com/cloudtrail/home#/events)
            - [State Bucket](https://us-east-2.console.aws.amazon.com/s3/buckets/${var.state_bucket_name})
            - [Logs Insights](https://us-east-2.console.aws.amazon.com/cloudwatch/home#logsV2:logs-insights)
          EOT
        }
      },

      {
        type   = "text"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          markdown = <<-EOT
            ## Audit Query Reference

            Run these in CloudWatch Logs Insights against your CloudTrail log group.

            **All Terraform activity (last 12 hours)**
            ```
            fields @timestamp, eventName, userIdentity.arn, sourceIPAddress
            | filter userAgent like /Terraform/
            | sort @timestamp desc | limit 50
            ```

            **SSM parameter changes for ${var.account}**
            ```
            fields @timestamp, eventName, requestParameters.name
            | filter eventSource = "ssm.amazonaws.com"
            | filter eventName in ["PutParameter","DeleteParameter"]
            | filter requestParameters.name like /${var.account}/
            | sort @timestamp desc | limit 20
            ```

            **Pipeline vs. manual changes**
            ```
            fields @timestamp, eventName, userIdentity.arn, sourceIPAddress
            | filter userIdentity.arn like /${var.account}-codebuild-terraform-role/
            | sort @timestamp desc | limit 50
            ```
          EOT
        }
      }
    ]
  })
}

output "dashboard_url" {
  description = "Direct URL to view this dashboard in the CloudWatch console."
  value       = "https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=${aws_cloudwatch_dashboard.terraform_ops.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the dashboard resource (useful for cross-referencing)."
  value       = aws_cloudwatch_dashboard.terraform_ops.dashboard_name
}
