# iam.tf - IAM Roles for Pipeline Components

# =============================================================================
# CodeBuild Service Role
# =============================================================================
# This role is assumed by CodeBuild projects. It needs permissions to:
# - Write build logs to CloudWatch
# - Read/write state files in S3 (including .tflock files for S3 native locking)
# - Manage the AWS resources that Terraform will create (EC2, ELB, ASG, SSM)

resource "aws_iam_role" "codebuild" {
  name = "${var.user_id}-codebuild-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.user_id}-codebuild-terraform-role"
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.user_id}-codebuild-terraform-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Covers both the build's own log stream and the log groups Terraform
        # creates for Lambda. Creating a tagged log group needs logs:TagResource
        # on top of CreateLogGroup, and retention_in_days needs
        # PutRetentionPolicy -- hence the wildcard rather than three actions.
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      },
      {
        Sid    = "S3StateAndArtifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*",
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Sid    = "TerraformManagedResources"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "ssm:*",
          # Task 8 (serverless bonus) swaps the EC2 module for Lambda +
          # API Gateway HTTP API. Without these the Apply-Staging stage fails.
          "lambda:*",
          "apigateway:*"
        ]
        Resource = "*"
      },
      {
        # The serverless module creates its own Lambda execution role and passes
        # it to the function, so the build role must be able to create, tag,
        # attach policies to, and pass a role. Scoped to this student's roles so
        # the build cannot touch anyone else's.
        Sid    = "LambdaExecutionRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = "arn:aws:iam::*:role/${var.user_id}-*"
      },
      {
        # Task 5 adds an `env: secrets-manager:` block to the apply buildspec.
        # CodeBuild resolves that with its OWN service role -- not the student's
        # IAM policy -- so without this the build fails during env resolution,
        # before any command runs. The matching `env: parameter-store:` lookup
        # is already covered by ssm:* above.
        Sid    = "SecretsManagerForBuildspecEnv"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# CodePipeline Service Role
# =============================================================================
# This role is assumed by CodePipeline. It needs permissions to:
# - Pull source code from CodeCommit
# - Trigger and monitor CodeBuild projects
# - Read/write pipeline artifacts in S3

resource "aws_iam_role" "codepipeline" {
  name = "${var.user_id}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.user_id}-codepipeline-role"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.user_id}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeCommitAccess"
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive",
          "codecommit:CancelUploadArchive"
        ]
        Resource = aws_codecommit_repository.terraform.arn
      },
      {
        Sid    = "CodeBuildAccess"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ArtifactAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}
