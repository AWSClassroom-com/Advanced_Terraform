# codebuild.tf - CodeBuild Projects for Terraform Pipeline

# =============================================================================
# Artifacts Bucket
# =============================================================================
# Pipeline artifacts (source code, plan files) are stored here between stages

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.student_id}-pipeline-artifacts"

  tags = {
    Name = "${var.student_id}-pipeline-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================================================
# Project 1: Validate
# =============================================================================
# Runs terraform fmt -check and terraform validate on all code
# This catches formatting errors and syntax issues BEFORE any plan is generated

resource "aws_codebuild_project" "validate" {
  name          = "${var.student_id}-terraform-validate"
  description   = "Terraform format check and validate"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - echo "=== Installing Terraform ==="
            - yum install -y yum-utils
            - yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
            - yum -y install terraform
            - terraform version
        build:
          commands:
            - echo "=== Running terraform fmt check ==="
            - terraform fmt -check -recursive
            - echo "=== Running terraform validate ==="
            - cd environments/staging
            - terraform init -backend=false
            - terraform validate
            - cd ../prod
            - terraform init -backend=false
            - terraform validate
            - echo "=== All validations passed ==="
    EOF
  }

  tags = {
    Name  = "${var.student_id}-terraform-validate"
    Stage = "validate"
  }
}

# =============================================================================
# Project 2: Plan Staging
# =============================================================================
# Generates a Terraform plan for the staging environment
# The plan file is saved as an artifact and passed to the apply stage

resource "aws_codebuild_project" "plan_staging" {
  name          = "${var.student_id}-terraform-plan-staging"
  description   = "Terraform plan for staging environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_environment"
      value = "staging"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - yum install -y yum-utils
            - yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
            - yum -y install terraform
        build:
          commands:
            - echo "=== Planning staging environment ==="
            - cd environments/staging
            - terraform init
            - terraform plan -out=tfplan
            - echo "=== Staging plan complete ==="
      artifacts:
        files:
          - environments/staging/tfplan
          - environments/staging/.terraform/**/*
          - environments/staging/.terraform.lock.hcl
          - modules/**/*
        base-directory: .
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-plan-staging"
    Stage       = "plan"
    Environment = "staging"
  }
}

# =============================================================================
# Project 3: Apply Staging
# =============================================================================
# Applies the previously generated plan to the staging environment
# Uses -auto-approve because the plan was already reviewed at the approval gate

resource "aws_codebuild_project" "apply_staging" {
  name          = "${var.student_id}-terraform-apply-staging"
  description   = "Terraform apply for staging environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - yum install -y yum-utils
            - yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
            - yum -y install terraform
        build:
          commands:
            - echo "=== Applying to staging environment ==="
            - cd environments/staging
            - terraform init
            - terraform apply -auto-approve tfplan
            - echo "=== Staging apply complete ==="
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-apply-staging"
    Stage       = "apply"
    Environment = "staging"
  }
}

# =============================================================================
# Project 4: Plan Production
# =============================================================================
# Generates a Terraform plan for the production environment
# Production uses us-west-2 region for geographic separation

resource "aws_codebuild_project" "plan_prod" {
  name          = "${var.student_id}-terraform-plan-prod"
  description   = "Terraform plan for production environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_environment"
      value = "prod"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - yum install -y yum-utils
            - yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
            - yum -y install terraform
        build:
          commands:
            - echo "=== Planning production environment ==="
            - cd environments/prod
            - terraform init
            - terraform plan -out=tfplan
            - echo "=== Production plan complete ==="
      artifacts:
        files:
          - environments/prod/tfplan
          - environments/prod/.terraform/**/*
          - environments/prod/.terraform.lock.hcl
          - modules/**/*
        base-directory: .
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-plan-prod"
    Stage       = "plan"
    Environment = "production"
  }
}

# =============================================================================
# Project 5: Apply Production
# =============================================================================
# Applies the previously generated plan to the production environment
# This is the final stage -- changes are now live in production

resource "aws_codebuild_project" "apply_prod" {
  name          = "${var.student_id}-terraform-apply-prod"
  description   = "Terraform apply for production environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - yum install -y yum-utils
            - yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
            - yum -y install terraform
        build:
          commands:
            - echo "=== Applying to production environment ==="
            - cd environments/prod
            - terraform init
            - terraform apply -auto-approve tfplan
            - echo "=== Production apply complete ==="
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-apply-prod"
    Stage       = "apply"
    Environment = "production"
  }
}
