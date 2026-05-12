# codecommit.tf - Source Repository

resource "aws_codecommit_repository" "terraform" {
  repository_name = "${var.student_id}-terraform-repo"
  description     = "Terraform code repository for ${var.student_id} - NovaTech pipeline"

  tags = {
    Name = "${var.student_id}-terraform-repo"
  }
}
