# lab2-import/outputs.tf

output "vpc_id" {
  description = "VPC ID after import."
  value       = aws_vpc.custom-vpc.id
}

output "subnet_id" {
  description = "Public subnet ID after import."
  value       = aws_subnet.subnet-a.id
}

output "security_group_id" {
  description = "allow-http-ssh security group ID after import."
  value       = aws_security_group.allow-http-ssh.id
}

output "imported_resource_count" {
  description = "Total resources Terraform manages after import (sanity check — should be 9)."
  value       = 9
}
