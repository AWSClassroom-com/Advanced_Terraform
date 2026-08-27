# lab4-observability/dashboard.tf
#
# One aws_cloudwatch_dashboard resource. Its dashboard_body is a JSON
# document, built here with jsonencode() so the widgets can reference
# Terraform variables instead of being pasted in as a literal string.
#
# Widgets are laid out on a 24-column grid: x and y are grid positions,
# width and height are grid units. Rows are grouped by comment below.
#
# Every region reference reads var.primary_region, so the dashboard follows
# wherever the class deploys.

resource "aws_cloudwatch_dashboard" "terraform_ops" {
  dashboard_name = "${var.user_id}-terraform-operations"

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
          markdown = "# Terraform Operations Dashboard — ${var.user_id}\n**User:** ${var.user_id} | **Region:** ${var.primary_region} | **State bucket:** `${var.state_bucket_name}`\n\nMonitors CI/CD pipeline health, state operations, and provides audit query references."
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
            ["AWS/CodeBuild", "Duration", "ProjectName", "${var.user_id}-terraform-validate"],
            ["...", "${var.user_id}-terraform-plan-staging"],
            ["...", "${var.user_id}-terraform-apply-staging"],
            ["...", "${var.user_id}-terraform-plan-prod"],
            ["...", "${var.user_id}-terraform-apply-prod"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.primary_region
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
            ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", "${var.user_id}-terraform-apply-staging"],
            [".", "FailedBuilds", ".", "."],
            [".", "SucceededBuilds", ".", "${var.user_id}-terraform-apply-prod"],
            [".", "FailedBuilds", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.primary_region
          title   = "Build Success vs. Failure (Apply stages)"
          period  = 3600
          stat    = "Sum"
        }
      },

      # The three widgets below replace an earlier set built on
      # AWS/CodePipeline metrics. Those metrics do not exist for this
      # pipeline: CodePipeline only began publishing CloudWatch metrics in
      # 2025 and only for V2 pipelines, and even then it publishes just
      # PipelineDuration and FailedPipelineExecutions - there is no
      # success metric at any pipeline type. CodeBuild, by contrast,
      # publishes SucceededBuilds, FailedBuilds, Builds and Duration per
      # project, and every pipeline stage here IS a CodeBuild project, so
      # the same questions get answered one level down.
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 8
        height = 4
        properties = {
          metrics = [
            ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", "${var.user_id}-terraform-apply-staging"],
            [".", "SucceededBuilds", ".", "${var.user_id}-terraform-apply-prod"]
          ]
          view   = "singleValue"
          region = var.primary_region
          title  = "Successful Applies (staging + prod)"
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
            ["AWS/CodeBuild", "FailedBuilds", "ProjectName", "${var.user_id}-terraform-validate"],
            [".", "FailedBuilds", ".", "${var.user_id}-terraform-plan-staging"],
            [".", "FailedBuilds", ".", "${var.user_id}-terraform-apply-staging"],
            [".", "FailedBuilds", ".", "${var.user_id}-terraform-plan-prod"],
            [".", "FailedBuilds", ".", "${var.user_id}-terraform-apply-prod"]
          ]
          view   = "singleValue"
          region = var.primary_region
          title  = "Failed Builds (all stages)"
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
            ["AWS/CodeBuild", "Builds", "ProjectName", "${var.user_id}-terraform-validate"],
            [".", "Builds", ".", "${var.user_id}-terraform-plan-staging"],
            [".", "Builds", ".", "${var.user_id}-terraform-apply-staging"],
            [".", "Builds", ".", "${var.user_id}-terraform-plan-prod"],
            [".", "Builds", ".", "${var.user_id}-terraform-apply-prod"]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.primary_region
          title   = "Build Activity by Stage"
          period  = 3600
          stat    = "Sum"
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
          region  = var.primary_region
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
          region  = var.primary_region
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

            - [CodePipeline → ${var.user_id}-terraform-pipeline](https://${var.primary_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${var.user_id}-terraform-pipeline/view)
            - [CodeBuild Projects](https://${var.primary_region}.console.aws.amazon.com/codesuite/codebuild/projects)
            - [CloudTrail Event History](https://${var.primary_region}.console.aws.amazon.com/cloudtrail/home#/events)
            - [State Bucket](https://${var.primary_region}.console.aws.amazon.com/s3/buckets/${var.state_bucket_name})
            - [Log Analytics](https://${var.primary_region}.console.aws.amazon.com/cloudwatch/home#logsV2:logs-insights)
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

            Run these in CloudWatch Log Analytics against your CloudTrail log group.

            **All Terraform activity (last 12 hours)**
            ```
            SOURCE logGroups(namePrefix: ["/aws/cloudtrail/advanced-terraform"]) START=-12h END=0s |
            fields eventTime, eventName, userIdentity.arn, sourceIPAddress
            | filter userAgent like /Terraform/
            | sort eventTime desc | limit 50
            ```

            **SSM parameter changes for ${var.user_id}**
            ```
            SOURCE logGroups(namePrefix: ["/aws/cloudtrail/advanced-terraform"]) START=-12h END=0s |
            fields eventTime, eventName, requestParameters.name
            | filter eventSource = "ssm.amazonaws.com"
            | filter eventName in ["PutParameter","DeleteParameter"]
            | filter requestParameters.name like /${var.user_id}/
            | sort eventTime desc | limit 20
            ```

            **Pipeline vs. manual changes**
            ```
            SOURCE logGroups(namePrefix: ["/aws/cloudtrail/advanced-terraform"]) START=-12h END=0s |
            fields eventTime, eventName, userIdentity.arn, sourceIPAddress
            | filter userIdentity.arn like /${var.user_id}-codebuild-terraform-role/
            | sort eventTime desc | limit 50
            ```
          EOT
        }
      }
    ]
  })
}

output "dashboard_url" {
  description = "Direct URL to view this dashboard in the CloudWatch console."
  value       = "https://${var.primary_region}.console.aws.amazon.com/cloudwatch/home?region=${var.primary_region}#dashboards:name=${aws_cloudwatch_dashboard.terraform_ops.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the dashboard resource (useful for cross-referencing)."
  value       = aws_cloudwatch_dashboard.terraform_ops.dashboard_name
}
