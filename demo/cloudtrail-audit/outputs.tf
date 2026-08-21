# demo/cloudtrail-audit/outputs.tf

output "log_group_name" {
  description = "Log group students select in Logs Insights for Lab 4 Task 2."
  value       = aws_cloudwatch_log_group.trail.name
}

output "trail_name" {
  description = "Name of the trail."
  value       = aws_cloudtrail.class.name
}

output "trail_bucket" {
  description = "Bucket holding the raw log files."
  value       = aws_s3_bucket.trail.id
}
