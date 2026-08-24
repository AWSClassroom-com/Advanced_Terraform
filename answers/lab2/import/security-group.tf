# lab2/import/security-group.tf
#
# Cleaned configuration for the security group + its 3 rules. Resource
# addresses match lab2/existing-stack/security-group.tf.
#
# Note: this uses the MODERN AWS rule pattern — separate
# aws_vpc_security_group_ingress_rule / egress_rule resources, NOT inline
# ingress {} / egress {} blocks. The modern pattern enables changes to
# individual rules without recreating the whole SG (important when the SG
# is already attached to running infrastructure).

resource "aws_security_group" "allow-http-ssh" {
  name        = "${var.user_id}-allow-http-ssh"
  description = "Enable HTTP and SSH Access"
  vpc_id      = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.user_id}-allow-http-ssh"
  }

  lifecycle {
    # Will be added in a later step; commented for now so the initial import succeeds.
    # Once imported and verified, uncomment to protect against accidental destroy.
    prevent_destroy = true
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
