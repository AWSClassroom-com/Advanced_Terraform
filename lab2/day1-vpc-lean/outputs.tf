# lab2-day1-vpc-lean/outputs.tf
#
# These outputs surface the resource IDs students need to paste into
# lab2-import/terraform.tfvars. Day 1-2's vpc/ module didn't expose these
# (it had no outputs.tf at all) — adding them here for the import flow.

output "vpc_id" {
  description = "ID of the imported VPC. Paste into lab2-import/terraform.tfvars."
  value       = aws_vpc.custom-vpc.id
}

output "subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.subnet-a.id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.igw.id
}

output "route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public_rt.id
}

output "route_table_association_id" {
  description = "ID of the route table association. Note: import expects compound ID `<subnet>/<rt>`, not this raw ID."
  value       = aws_route_table_association.public_subnet_a.id
}

output "import_compound_id_rt_assoc" {
  description = "The compound ID format Terraform import requires for aws_route_table_association: `<subnet-id>/<route-table-id>`."
  value       = "${aws_subnet.subnet-a.id}/${aws_route_table.public_rt.id}"
}

# ---------------------------------------------------------------------------
# Security group + 3 rule IDs for the import flow.
# ---------------------------------------------------------------------------

output "security_group_id" {
  description = "ID of the allow-http-ssh security group (sg-...)."
  value       = aws_security_group.allow-http-ssh.id
}

output "sg_rule_http_id" {
  description = "ID of the HTTP ingress rule (sgr-...)."
  value       = aws_vpc_security_group_ingress_rule.allow-http-ipv4.security_group_rule_id
}

output "sg_rule_ssh_id" {
  description = "ID of the SSH ingress rule (sgr-...)."
  value       = aws_vpc_security_group_ingress_rule.allow-ssh-ipv4.security_group_rule_id
}

output "sg_rule_egress_id" {
  description = "ID of the all-outbound egress rule (sgr-...)."
  value       = aws_vpc_security_group_egress_rule.allow-all-outbound.security_group_rule_id
}
