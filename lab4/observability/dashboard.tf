# lab4-observability/dashboard.tf
#
# One aws_cloudwatch_dashboard resource. Its dashboard_body is a JSON
# document, built here with jsonencode() so the widgets can reference
# Terraform variables instead of being pasted in as a literal string.
#
# Widgets are laid out on a 24-column grid: x and y are grid positions,
# width and height are grid units. Rows are grouped by comment below.
#
# Every region reference reads var.region, so the dashboard follows
# wherever the class deploys.

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
          markdown = "# Terraform Operations Dashboard — ${var.account}\n**Account:** ${var.account} | **Region:** ${var.region} | **State bucket:** `${var.state_bucket_name}`\n\nMonitors CI/CD pipeline health, state operations, and provides audit query references."
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
          region  = var.region
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
          region  = var.region
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
          region = var.region
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
          region = var.region
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
          region  = var.region
          title   = "Pipeline Executions Over Time"
          period  = 3600
        }
      },

      # ---------------------------------------------------------------
      # Row 2: State & Infrastructure Operations
      # ---------------------------------------------------------------
      #
      # NOTE: BucketName is var.state_bucket_name (the actual bucket name
      # with random suffix), NOT a constructed string.
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
          region  = var.region
          title   = "State Bucket Operations (Get = plan, Put = apply)"
          period  = 300
          stat    = "Sum"
        }
      },

      # State bucket PutRequests. Lock and unlock show up inside this
      # total: request metrics filter on a key prefix, and .tflock is a suffix.
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "PutRequests", "BucketName", var.state_bucket_name, "FilterId", "EntireBucket"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "State Bucket PutRequests (state writes + .tflock lock/unlock)"
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

            - [CodePipeline → ${var.account}-terraform-pipeline](https://${var.region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${var.account}-terraform-pipeline/view)
            - [CodeBuild Projects](https://${var.region}.console.aws.amazon.com/codesuite/codebuild/projects)
            - [CloudTrail Event History](https://${var.region}.console.aws.amazon.com/cloudtrail/home#/events)
            - [State Bucket](https://${var.region}.console.aws.amazon.com/s3/buckets/${var.state_bucket_name})
            - [Logs Insights](https://${var.region}.console.aws.amazon.com/cloudwatch/home#logsV2:logs-insights)
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
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.terraform_ops.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the dashboard resource (useful for cross-referencing)."
  value       = aws_cloudwatch_dashboard.terraform_ops.dashboard_name
}
