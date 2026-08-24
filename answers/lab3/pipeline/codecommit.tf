# codecommit.tf - Source Repository

resource "aws_codecommit_repository" "terraform" {
  repository_name = "${var.user_id}-terraform-repo"
  description     = "Terraform code repository for ${var.user_id} - NovaTech pipeline"

  tags = {
    Name = "${var.user_id}-terraform-repo"
  }
}
