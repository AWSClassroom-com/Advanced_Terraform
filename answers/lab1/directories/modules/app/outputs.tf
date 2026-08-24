# lab1-directories/modules/app/outputs.tf

output "app_config_parameter_name" {
  description = "Full SSM parameter path where the app config JSON is stored."
  value       = aws_ssm_parameter.app_config.name
}

output "networking_vpc_id" {
  description = "VPC ID resolved via terraform_remote_state. Useful for verifying the cross-state read worked."
  value       = data.terraform_remote_state.networking.outputs.vpc_id
}
