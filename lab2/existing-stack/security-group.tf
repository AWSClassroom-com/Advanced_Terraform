# lab2/existing-stack/security-group.tf
#
# The `allow-http-ssh` security group with its 3 modern rule resources, as
# Lab 2 expects to find and import them.
#
# Note: Modern AWS rule pattern (separate aws_vpc_security_group_*_rule
# resources) — NOT inline ingress {} / egress {} blocks. Imports later
# need separate IDs for the SG and each rule.

variable "security_group_name" {
  description = "Name suffix for the security group."
  type        = string
  default     = "allow-http-ssh"
}

resource "aws_security_group" "allow-http-ssh" {
  name        = "${var.user_id}-${var.security_group_name}"
  description = "Enable HTTP and SSH Access"
  vpc_id      = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.user_id}-${var.security_group_name}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-http-ipv4" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh-ipv4" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow-all-outbound" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
