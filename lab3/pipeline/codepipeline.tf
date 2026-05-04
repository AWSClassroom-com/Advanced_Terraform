# codepipeline.tf - Pipeline Definition
# Orchestrates the full Terraform deployment workflow across environments

resource "aws_codepipeline" "terraform" {
  name     = "${var.student_id}-terraform-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # =========================================================================
  # Stage 1: Source
  # =========================================================================
  # Triggers automatically when code is pushed to the main branch

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.terraform.repository_name
        BranchName     = "main"
      }
    }
  }

  # =========================================================================
  # Stage 2: Validate
  # =========================================================================
  # Runs fmt check and validate on all Terraform code

  stage {
    name = "Validate"

    action {
      name             = "Terraform-Validate"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["validate_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.validate.name
      }
    }
  }

  # =========================================================================
  # Stage 3: Plan Staging
  # =========================================================================
  # Generates a Terraform plan for staging; plan file becomes an artifact

  stage {
    name = "Plan-Staging"

    action {
      name             = "Terraform-Plan-Staging"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["staging_plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.plan_staging.name
      }
    }
  }

  # =========================================================================
  # Stage 4: Approve Staging
  # =========================================================================
  # Manual approval gate - reviewer must approve before staging deploy

  stage {
    name = "Approve-Staging"

    action {
      name     = "Approve-Staging-Deploy"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Review the Terraform plan for STAGING and approve to deploy. Check the Plan-Staging build logs for details."
      }
    }
  }

  # =========================================================================
  # Stage 5: Apply Staging
  # =========================================================================
  # Applies the approved plan to staging environment (us-east-1)

  stage {
    name = "Apply-Staging"

    action {
      name            = "Terraform-Apply-Staging"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["staging_plan_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.apply_staging.name
      }
    }
  }

  # =========================================================================
  # Stage 6: Plan Production
  # =========================================================================
  # Generates a Terraform plan for production; uses source_output (not staging)

  stage {
    name = "Plan-Production"

    action {
      name             = "Terraform-Plan-Prod"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["prod_plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.plan_prod.name
      }
    }
  }

  # =========================================================================
  # Stage 7: Approve Production
  # =========================================================================
  # Manual approval gate - PRODUCTION requires careful review

  stage {
    name = "Approve-Production"

    action {
      name     = "Approve-Production-Deploy"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "PRODUCTION DEPLOYMENT - Review the production plan carefully before approving. This will modify live infrastructure."
      }
    }
  }

  # =========================================================================
  # Stage 8: Apply Production
  # =========================================================================
  # Applies the approved plan to production environment (us-west-2)

  stage {
    name = "Apply-Production"

    action {
      name            = "Terraform-Apply-Prod"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["prod_plan_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.apply_prod.name
      }
    }
  }

  tags = {
    Name = "${var.student_id}-terraform-pipeline"
  }
}

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.terraform.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.terraform.arn
}
