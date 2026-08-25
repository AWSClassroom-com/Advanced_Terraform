# codebuild.tf - CodeBuild Projects for Terraform Pipeline

# =============================================================================
# Artifacts Bucket
# =============================================================================
# Pipeline artifacts (source code, plan files) are stored here between stages.
# A random suffix keeps the bucket name globally unique even when multiple
# cohorts run the lab with the same user_id (S3 bucket names are global).

resource "random_string" "artifacts_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.user_id}-pipeline-artifacts-${random_string.artifacts_suffix.result}"

  tags = {
    Name = "${var.user_id}-pipeline-artifacts-${random_string.artifacts_suffix.result}"
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
  name          = "${var.user_id}-terraform-validate"
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

    environment_variable {
      name  = "TF_VAR_user_id"
      value = var.user_id
    }

    environment_variable {
      name  = "STATE_BUCKET"
      value = var.state_bucket_name
    }

    environment_variable {
      name  = "BUCKET_REGION"
      value = var.bucket_region
    }
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
    Name  = "${var.user_id}-terraform-validate"
    Stage = "validate"
  }
}

# =============================================================================
# Project 2: Plan Staging
# =============================================================================
# Generates a Terraform plan for the staging environment
# The plan file is saved as an artifact and passed to the apply stage

resource "aws_codebuild_project" "plan_staging" {
  name          = "${var.user_id}-terraform-plan-staging"
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
      name  = "TF_VAR_user_id"
      value = var.user_id
    }

    environment_variable {
      name  = "STATE_BUCKET"
      value = var.state_bucket_name
    }

    environment_variable {
      name  = "BUCKET_REGION"
      value = var.bucket_region
    }
  }

  source {
    type = "CODEPIPELINE"
    # Lab 3 Steps 20-21: secrets are resolved at PLAN time, not apply time.
    # `terraform apply tfplan` refuses variables alongside a saved plan, so the
    # values have to be baked into tfplan while it is being created.
    #
    # ${var.user_id} interpolates because this heredoc is <<-EOF, not <<-'EOF'.
    # The lab text says to substitute your own userXX; using the variable is the
    # better form and is what makes this file work for every student unedited.
    buildspec = <<-EOF
      version: 0.2
      env:
        parameter-store:
          DB_HOST: /${var.user_id}/lab3/db_host
        secrets-manager:
          DB_PASSWORD: ${var.user_id}/lab3/db_password
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
            - export TF_VAR_db_host="$DB_HOST"
            - export TF_VAR_db_password="$DB_PASSWORD"
            - terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="region=$BUCKET_REGION"
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
    Name        = "${var.user_id}-terraform-plan-staging"
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
  name          = "${var.user_id}-terraform-apply-staging"
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

    environment_variable {
      name  = "TF_VAR_user_id"
      value = var.user_id
    }

    environment_variable {
      name  = "STATE_BUCKET"
      value = var.state_bucket_name
    }

    environment_variable {
      name  = "BUCKET_REGION"
      value = var.bucket_region
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
            - echo "=== Applying to staging environment ==="
            - cd environments/staging
            - terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="region=$BUCKET_REGION"
            - terraform apply -auto-approve tfplan
            - echo "=== Staging apply complete ==="
    EOF
  }

  tags = {
    Name        = "${var.user_id}-terraform-apply-staging"
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
  name          = "${var.user_id}-terraform-plan-prod"
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
      name  = "TF_VAR_user_id"
      value = var.user_id
    }

    environment_variable {
      name  = "STATE_BUCKET"
      value = var.state_bucket_name
    }

    environment_variable {
      name  = "BUCKET_REGION"
      value = var.bucket_region
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
            - terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="region=$BUCKET_REGION"
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
    Name        = "${var.user_id}-terraform-plan-prod"
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
  name          = "${var.user_id}-terraform-apply-prod"
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

    environment_variable {
      name  = "TF_VAR_user_id"
      value = var.user_id
    }

    environment_variable {
      name  = "STATE_BUCKET"
      value = var.state_bucket_name
    }

    environment_variable {
      name  = "BUCKET_REGION"
      value = var.bucket_region
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
            - echo "=== Applying to production environment ==="
            - cd environments/prod
            - terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="region=$BUCKET_REGION"
            - terraform apply -auto-approve tfplan
            - echo "=== Production apply complete ==="
    EOF
  }

  tags = {
    Name        = "${var.user_id}-terraform-apply-prod"
    Stage       = "apply"
    Environment = "production"
  }
}
