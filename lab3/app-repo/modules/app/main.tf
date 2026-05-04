# modules/app/main.tf - Shared application module
# This module defines the application configuration for any environment.
# It uses SSM Parameter Store to demonstrate real infrastructure changes
# flowing through the pipeline without incurring significant costs.

resource "aws_ssm_parameter" "app_config" {
  name        = "/${var.student_id}/${var.environment}/app-config"
  description = "Application configuration for ${var.environment}"
  type        = "String"
  value       = "environment=${var.environment},instances=${var.instance_count},version=1.0.0"

  tags = {
    Name        = "${var.student_id}-${var.environment}-config"
    Environment = var.environment
    Student     = var.student_id
  }
}

resource "aws_ssm_parameter" "deploy_timestamp" {
  name        = "/${var.student_id}/${var.environment}/last-deploy"
  description = "Timestamp of last deployment to ${var.environment}"
  type        = "String"
  value       = timestamp()

  tags = {
    Name        = "${var.student_id}-${var.environment}-deploy-timestamp"
    Environment = var.environment
    Student     = var.student_id
  }

  lifecycle {
    ignore_changes = [value]
  }
}

output "config_parameter_name" {
  description = "Name of the application config parameter"
  value       = aws_ssm_parameter.app_config.name
}
