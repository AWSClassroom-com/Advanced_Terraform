# Lab 2 answers

Complete code for **Import Existing Infrastructure into Remote State**, including the Challenge.

| File | What differs |
|---|---|
| `import/imports.tf` | **Step 8** — the four security group import blocks. The five VPC-stack blocks ship complete in the lab; these are the ones you write. |
| `import/network.tf`, `import/security-group.tf` | **Task 5** — `prevent_destroy` uncommented, as you leave it at the end of Step 15. |
| `import/generate-config-demo/generated.tf` | **The Challenge** — the generated configuration after cleanup. Does not exist in the lab directory; you produce it with `-generate-config-out` and then clean it. |

## Step 8

Order matters. The security group has to import before its rules, because each rule references the
SG ID:

```hcl
import {
  to = aws_security_group.allow-http-ssh
  id = var.security_group_id
}
```

If `terraform plan` reports `5 to import, 4 to add` rather than `9 to import`, a block is missing
or its `to` address is wrong — Terraform found configuration it has no instruction to import, so it
plans to build a second security group.

## The Challenge

`generated.tf` here is what a correct cleanup looks like. It keeps the CIDRs as literals, because
`generate-config-demo/` declares no `vpc_cidr` / `public_subnet_cidr` variables. The shipped
`lab2/import/network.tf` goes one step further and moves them into variables, which is why the main
import directory declares those two and this one does not.

```bash
cd ~/Advanced_Terraform/lab2/import/generate-config-demo
terraform plan
```
```
Plan: 9 to import, 0 to add, 0 to change, 0 to destroy.
```

Do not `apply` here. Those resources are already managed by the state you imported into in Task 4.
