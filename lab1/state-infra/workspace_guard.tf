# workspace_guard.tf
# Lab 1 Task 3 — Workspace Safety Guard
#
# Prevents accidental operations in the wrong workspace by attaching
# preconditions to a null_resource. Preconditions evaluate during
# `terraform plan`, so invalid workspaces are caught before any real
# resources are touched.

locals {
  # Workspaces permitted for normal operation. Feature-branch workspaces
  # (`feature-*`) are also allowed for short-lived testing.
  allowed_workspaces = ["dev", "staging", "prod"]

  # Production requires extra caution downstream.
  is_production = terraform.workspace == "prod"
}

resource "null_resource" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = terraform.workspace != "default"
      error_message = <<-EOT
        ERROR: Cannot run Terraform in 'default' workspace.

        Please select an environment workspace:
          terraform workspace select dev
          terraform workspace select staging
          terraform workspace select prod

        Or create a new workspace:
          terraform workspace new dev
      EOT
    }

    precondition {
      condition     = contains(local.allowed_workspaces, terraform.workspace) || startswith(terraform.workspace, "feature-")
      error_message = <<-EOT
        ERROR: Workspace '${terraform.workspace}' is not allowed.

        Allowed workspaces: ${join(", ", local.allowed_workspaces)}
        Or use a feature branch workspace: feature-*
      EOT
    }
  }
}

# Surfaces a visible reminder when operating against production.
output "production_warning" {
  value = local.is_production ? "WARNING: You are operating in PRODUCTION!" : null
}
