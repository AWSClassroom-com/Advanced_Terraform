# Lab 2: Import Day 1-2 Infrastructure into Remote State

Bring the existing Day 1-2 VPC + Security Group under proper remote-state Terraform management. **9 resources imported**, S3 state bucket deliberately not imported (it's already managed by Day 1-2's `module.s3_bucket` in `aws/s3-bucket/`).

## Subfolders

| Folder | Used for |
|--------|----------|
| [`day1-vpc-lean/`](./day1-vpc-lean/) | Fallback for students whose Day 1-2 VPC was destroyed at end of class. Deploys the same resource names as Day 1-2 `aws/vpc/` + `aws/security-group/` minus the NAT Gateway (~$1/day saved). |
| [`import/`](./import/) | The actual Lab 2 working directory. 9 import blocks (5 VPC + 1 SG + 3 rules), cleaned config files (`network.tf`, `security-group.tf`), and `outputs.tf`. Imports happen in the **dev** workspace. |

## Resources imported (in order)

1. `aws_vpc.custom-vpc`
2. `aws_subnet.subnet-a`
3. `aws_internet_gateway.igw`
4. `aws_route_table.public_rt`
5. `aws_route_table_association.public_subnet_a` (compound import ID `<subnet>/<rt>`)
6. `aws_security_group.allow-http-ssh`
7. `aws_vpc_security_group_ingress_rule.allow-http-ipv4`
8. `aws_vpc_security_group_ingress_rule.allow-ssh-ipv4`
9. `aws_vpc_security_group_egress_rule.allow-all-outbound`

NAT Gateway, ALB, ALB SG, and the for_each subnet refactor are intentionally out of scope.

## Why no S3?

The state bucket is already managed by Day 1-2. Importing it into a second state would create dual-management — both states would think they own it, and the next `terraform apply` from either side could break the other. Plus you generally don't experiment with state buckets in import labs.
