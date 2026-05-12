# outputs.tf
# Pipeline outputs consumed by students (and downstream demos).
#
# These outputs were previously defined inline in codecommit.tf and
# codepipeline.tf. Consolidating them here matches the file table in
# the Day 3 Lab 3 instructions and keeps surface-area visible in one
# place.

# ---------- CodeCommit repository ----------

output "repository_clone_url_http" {
  description = "HTTP clone URL for the repository"
  value       = aws_codecommit_repository.terraform.clone_url_http
}

output "repository_clone_url_ssh" {
  description = "SSH clone URL for the repository"
  value       = aws_codecommit_repository.terraform.clone_url_ssh
}

output "repository_arn" {
  description = "ARN of the CodeCommit repository"
  value       = aws_codecommit_repository.terraform.arn
}

# ---------- CodePipeline ----------

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.terraform.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.terraform.arn
}
