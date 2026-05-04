# lab1-networking/outputs.tf
#
# These outputs are what the application state (lab1-state-infra) reads via
# terraform_remote_state. Adding/removing outputs here is a contract change
# for downstream consumers — bump cautiously.

output "vpc_id" {
  description = "ID of the shared networking VPC. Consumed by application states via terraform_remote_state."
  value       = aws_vpc.shared.id
}

output "subnet_id" {
  description = "ID of the shared public subnet. Application teams place their EC2 instances here in the lab simulation."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the shared application security group (HTTP open). Application teams attach this to their instances."
  value       = aws_security_group.shared_app.id
}

output "internet_gateway_id" {
  description = "ID of the shared internet gateway. Useful for app teams that need to add route table entries."
  value       = aws_internet_gateway.shared.id
}

output "vpc_cidr" {
  description = "CIDR block of the shared VPC. App teams use this to scope their own security group rules."
  value       = aws_vpc.shared.cidr_block
}
