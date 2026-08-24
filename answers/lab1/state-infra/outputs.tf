# outputs.tf
# Outputs used to configure the backend block in downstream projects and
# to surface the Part D cross-state results.

# ============================================================================
# IMPORTANT: Copy this value into your other labs' backend blocks
# ============================================================================

output "state_bucket_name" {
  description = "S3 bucket name - use this for 'bucket' in backend config"
  value       = aws_s3_bucket.terraform_state.id
}

# ----------------------------------------------------------------------------
# Part D cross-state outputs
# Both of these are null until `state_bucket_name` is set in terraform.tfvars
# (Part C Step 19) and lab1/networking has been deployed. Once Part D springs
# to life, they surface the SSM parameter name and the VPC ID the lab reads
# from networking's remote state.
# ----------------------------------------------------------------------------

output "app_config_ssm_parameter" {
  description = "SSM parameter name created by Part D's app_config resource. Null until Part D is enabled."
  value       = length(aws_ssm_parameter.app_config) > 0 ? aws_ssm_parameter.app_config[0].name : null
}

output "networking_vpc_id" {
  description = "VPC ID read from lab1/networking remote state. Null until Part D is enabled."
  value       = local.cross_state_enabled ? data.terraform_remote_state.networking[0].outputs.vpc_id : null
}
