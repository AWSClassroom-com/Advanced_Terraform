# iam.tf - IAM Roles for Pipeline Components

# =============================================================================
# CodeBuild Service Role
# =============================================================================
# This role is assumed by CodeBuild projects. It needs permissions to:
# - Write build logs to CloudWatch
# - Read/write state files in S3 (including .tflock files for S3 native locking)
# - Manage the AWS resources that Terraform will create (EC2, ELB, ASG, SSM)

resource "aws_iam_role" "codebuild" {
  name = "${var.student_id}-codebuild-terraform-role"

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
    Name = "${var.student_id}-codebuild-terraform-role"
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.student_id}-codebuild-terraform-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
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
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts",
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts/*"
        ]
      },
      {
        Sid    = "TerraformManagedResources"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "ssm:*"
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
  name = "${var.student_id}-codepipeline-role"

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
    Name = "${var.student_id}-codepipeline-role"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.student_id}-codepipeline-policy"
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
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts",
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts/*"
        ]
      }
    ]
  })
}
