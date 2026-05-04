# codecommit.tf - Source Repository

resource "aws_codecommit_repository" "terraform" {
  repository_name = "${var.student_id}-terraform-repo"
  description     = "Terraform code repository for ${var.student_id} - NovaTech pipeline"

  tags = {
    Name = "${var.student_id}-terraform-repo"
  }
}

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
