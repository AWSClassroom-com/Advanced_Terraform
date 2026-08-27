# lab1-directories/modules/app/main.tf
#
# The shared application module. Both dev/ and staging/ instantiate this
# with different `environment` values. Reads VPC info from the networking
# state via terraform_remote_state — same pattern as the workspace-based
# Lab 1 Task 4, just sourced from an explicit variable instead of workspace.

data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "networking/terraform.tfstate"
    region = var.bucket_region
  }
}

resource "aws_ssm_parameter" "app_config" {
  name = "/${var.user_id}/${var.environment}/app-config-dir"
  type = "String"

  value = jsonencode({
    environment       = var.environment
    vpc_id            = data.terraform_remote_state.networking.outputs.vpc_id
    subnet_id         = data.terraform_remote_state.networking.outputs.subnet_id
    security_group_id = data.terraform_remote_state.networking.outputs.security_group_id
    pattern           = "directory-structure"
    deployed_at       = timestamp()
  })

  tags = {
    Environment = var.environment
    Pattern     = "directory-structure"
  }
}
