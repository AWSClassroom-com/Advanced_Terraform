# Lab 2: Import Existing Infrastructure into Remote State

> 📖 **Student instructions:** [`../labs/lab2.md`](../labs/lab2.md)
>
> The Terraform code in this folder is what students run during the lab; the step-by-step instructions live in the `labs/` folder at the repo root.

Bring a VPC + Security Group stack that exists outside Terraform under proper remote-state management. **9 resources imported**, S3 state bucket deliberately not imported (it is already managed by `lab1/state-infra`).

## Subfolders

| Folder | Used for |
|--------|----------|
| [`existing-stack/`](./existing-stack/) | The stack students import. Deployed in Task 1 with **local state**, so it plays the role of infrastructure that exists outside any remote state. No NAT Gateway. |
| [`import/`](./import/) | The actual Lab 2 working directory. `imports.tf` ships the 5 VPC-stack import blocks; students write the 4 security-group blocks in Step 8. Cleaned config files (`network.tf`, `security-group.tf`) and `outputs.tf`. Imports happen in the **dev** workspace. |

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

The state bucket is already managed by `lab1/state-infra`. Importing it into a second state would create dual-management — both states would think they own it, and the next `terraform apply` from either side could break the other. Plus you generally don't experiment with state buckets in import labs.
