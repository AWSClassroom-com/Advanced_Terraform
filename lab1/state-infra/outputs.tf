# outputs.tf
# Outputs used to configure the backend block in downstream projects

# ============================================================================
# IMPORTANT: Copy this value into your other labs' backend blocks
# ============================================================================

output "state_bucket_name" {
  description = "S3 bucket name - use this for 'bucket' in backend config"
  value       = aws_s3_bucket.terraform_state.id
}
