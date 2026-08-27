# outputs.tf
# Outputs used to configure the backend block in downstream projects and
# to surface the Task 4 cross-state results.

# ============================================================================
# IMPORTANT: Copy this value into your other labs' backend blocks
# ============================================================================

output "state_bucket_name" {
  description = "S3 bucket name - use this for 'bucket' in backend config"
  value       = aws_s3_bucket.terraform_state.id
}

# ----------------------------------------------------------------------------
# Task 4 cross-state outputs
# Both of these are null until `state_bucket_name` is set in terraform.tfvars
# (Step 18) and lab1/networking has been deployed. Once the block springs
# to life, they surface the SSM parameter name and the VPC ID the lab reads
# from networking's remote state.
# ----------------------------------------------------------------------------

output "app_config_ssm_parameter" {
  description = "SSM parameter name created by Task 4's app_config resource. Null until Step 18 sets state_bucket_name."
  value       = length(aws_ssm_parameter.app_config) > 0 ? aws_ssm_parameter.app_config[0].name : null
}

output "networking_vpc_id" {
  description = "VPC ID read from lab1/networking remote state. Null until Step 18 sets state_bucket_name."
  value       = local.cross_state_enabled ? data.terraform_remote_state.networking[0].outputs.vpc_id : null
}
