# Lab 2: Import Existing Infrastructure into Remote State

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Chapter** | Importing Existing Infrastructure into Terraform |
| **Duration** | 45 minutes |
| **Difficulty** | Advanced |
| **Version** | 4.0 (9-resource import, S3 intentionally excluded) |
| **Prerequisites** | Lab 1 completed (workspaces, S3 backend with `use_lockfile`) |
| **Terraform** | >= 1.10.0 |
| **AWS Provider** | `~> 6.0` |
| **Lab Files** | [github.com/AWSClassroom-com/Advanced_Terraform](https://github.com/AWSClassroom-com/Advanced_Terraform) → `lab2/` |
---

## Lab Overview

### Narrative

A VPC, a public subnet, an internet gateway, a route table, and an `allow-http-ssh` security group
already exist in your AWS account. Another team built them, and they were never put under your
Terraform management. There is no state file that owns them.

That is the situation import blocks exist for. Today you will bring those nine resources into a
fresh, well-organized Terraform configuration under your **dev** workspace, using the workspace and
remote-state patterns from Lab 1. You will also see what `-generate-config-out` produces when you
ask Terraform to write the configuration for you, and why its output is a starting point rather
than a finished file.

You will deploy the "already exists" stack yourself in Task 1, because the classroom account starts
empty. It uses **local state** and is deliberately not part of any remote state, which is exactly
the position real unmanaged infrastructure is in.

> **Why no S3 bucket?** The S3 state bucket is **already** managed by `lab1/state-infra`'s state.
> Importing it into a second state would create dual-management — both states would think they own
> the bucket, and the next `terraform apply` from either side could break the other. Beyond that,
> destroying or drifting your state bucket means losing access to every other lab's state. We
> import the VPC and SG stack only.

### Learning Objectives

By the end of this lab, you will:

- **Reuse Lab 1's workspace pattern** to import resources into the **dev** workspace specifically
- **Write import blocks** (Terraform 1.5+) declaring resources to bring under management
- **Experience config generation** and understand its limitations (the cleanup pattern)
- **Import 9 resources** following dependency order (5 VPC stack + SG + 3 modern rule resources)
- **Achieve a clean plan** ("No changes") as proof of successful import
- **Add lifecycle protection** to critical resources (`prevent_destroy`)

---

## Resources to Import (9 total)

| # | Resource address | Notes |
|---|------------------|-------|
| 1 | `aws_vpc.custom-vpc` | VPC must be first (others depend on it) |
| 2 | `aws_subnet.subnet-a` | Single public subnet |
| 3 | `aws_internet_gateway.igw` | |
| 4 | `aws_route_table.public_rt` | |
| 5 | `aws_route_table_association.public_subnet_a` | **Compound import ID** `<subnet>/<rt>` |
| 6 | `aws_security_group.allow-http-ssh` | |
| 7 | `aws_vpc_security_group_ingress_rule.allow-http-ipv4` | Modern rule resource |
| 8 | `aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` | Modern rule resource |
| 9 | `aws_vpc_security_group_egress_rule.allow-all-outbound` | Modern rule resource |

The VPC stack imports in dependency order (VPC → subnet → IGW → route table → RT association). The
security group must import before its rules, because the rules reference the SG ID.

**What is intentionally NOT here:**
- **NAT Gateway** — not needed for this lab's lesson, and it bills by the hour.
- **S3 state bucket** — already managed by `lab1/state-infra`. See "Why no S3 bucket?" above.
- **Load balancer and auto scaling group** — not relevant to the import lesson.

---

## Task 1: Deploy the Stack You Will Import (10 min)

1. **Deploy the standalone VPC stack**

    ```bash
    cd ~/Advanced_Terraform/lab2/existing-stack
    cp terraform.tfvars.example terraform.tfvars
    ```

    Edit `terraform.tfvars` and set **both** values. Neither has a default, so leaving either one
    empty fails with "No value for required variable":

    ```hcl
    user_id        = "userxx"     # your assigned AWS login ID, for example user07
    primary_region = "us-east-2"  # your assigned deployment region
    ```

    Then:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```
    Review the plan, then type `yes` at the apply prompt.

    > **Why local state?** This stack uses **local state by design** — there is no backend block in
    > its `providers.tf`. It is playing the role of infrastructure that exists outside your remote
    > state, which is the whole premise of the lab. Do not move it to S3.

2. **Read the 8 resource IDs**

    ```bash
    terraform output
    ```
    The output names match the import project's variable names 1:1:
    - **VPC stack** — `vpc_id`, `subnet_id`, `internet_gateway_id`, `route_table_id`
    - **Security group and rules** — `security_group_id`, `sg_rule_http_id`, `sg_rule_ssh_id`, `sg_rule_egress_id`

    You also need your **state bucket name and the region the bucket is in**. This is the bucket
    Lab 1 created:

    ```bash
    aws s3 ls | grep terraform-state
    aws s3api get-bucket-location --bucket "<your-bucket-name>" --query 'LocationConstraint' --output text
    ```
    The bucket name looks like `user07-terraform-state-x8k2m4`. The bucket's region **may or may
    not match** the region you just deployed into. The state bucket and the resources you are
    importing are independent of each other.

---

## Task 2: Set Up the Import Project (8 min)

3. **Configure the import project**

    ```bash
    cd ~/Advanced_Terraform/lab2/import
    cp terraform.tfvars.example terraform.tfvars
    ```

    Edit `terraform.tfvars` with the IDs from Step 2. `primary_region` here is where the resources
    you are importing actually live — the same region you deployed into in Task 1.

    ```hcl
    user_id        = "userxx"
    primary_region = "us-east-2"

    # VPC stack
    vpc_id              = "vpc-0xxxxxxxxxxxxxxxx"
    subnet_id           = "subnet-0xxxxxxxxxxxxxxxx"
    internet_gateway_id = "igw-0xxxxxxxxxxxxxxxx"
    route_table_id      = "rtb-0xxxxxxxxxxxxxxxx"

    # Security group + 3 rules
    security_group_id   = "sg-0xxxxxxxxxxxxxxxx"
    sg_rule_http_id     = "sgr-0xxxxxxxxxxxxxxxx"
    sg_rule_ssh_id      = "sgr-0xxxxxxxxxxxxxxxx"
    sg_rule_egress_id   = "sgr-0xxxxxxxxxxxxxxxx"
    ```

4. **Review the backend config**

    Open `providers.tf` — the backend block does NOT hard-code the bucket name or region:

    ```hcl
    backend "s3" {
      key          = "imported/terraform.tfstate"   # Workspace prefix env:/dev/ added automatically
      encrypt      = true
      use_lockfile = true                            # Terraform 1.10+ S3 native locking
    }
    ```
    Bucket and region are passed at init time instead, so the same `providers.tf` works for every
    student in every region without edits.

    > **Two regions, kept separate.** `primary_region` in tfvars configures the AWS *provider* — where
    > the resources you are importing live. The region you pass at `terraform init` configures the
    > *S3 backend* — where the state bucket lives. These can differ, and confusing them is the most
    > common cause of `BucketRegionError: bucket is in a different region` at init time.

    > **Why a different state key from Lab 1?** Lab 1 uses key `lab1-app/terraform.tfstate`. This lab
    > uses `imported/terraform.tfstate`. Same bucket, separate state files — that is the multi-state
    > pattern.

5. **Initialize with backend config and select the dev workspace**

    Pass the **state bucket name** and the **bucket's region** from Step 2:

    ```bash
    terraform init \
        -backend-config="bucket=userXX-terraform-state-SUFFIX" \
        -backend-config="region=us-east-2"
    ```

    ```bash
    terraform workspace new dev    # creates if missing — an error here is fine if it already exists
    terraform workspace select dev
    terraform workspace show
    ```
    **Expected:**

    ```
    dev
    ```

    > **Why the dev workspace specifically?** The pattern Lab 1 introduced has imports landing in
    > **dev**, where the existing system actually lives. Lab 3's pipeline will apply this same
    > configuration to staging and prod, creating equivalent new resources there rather than
    > importing.

---

## Task 3: Experience Config Generation (7 min)

Terraform 1.5+ can attempt to **generate configuration from existing AWS resources**. You will run
it against the same nine resources to see what it produces.

> **Why a separate folder for this?** `lab2/import/` ships with cleaned `network.tf` and
> `security-group.tf` for the real import in Task 4. Running `-generate-config-out` there would
> find every resource already configured and write nothing. The `generate-config-demo/` subfolder
> deliberately omits those files so generation has work to do. It uses local state and never runs
> `terraform apply`.

6. **Run config generation**

    ```bash
    cd ~/Advanced_Terraform/lab2/import/generate-config-demo

    # Reuse the IDs you already pasted into the parent directory
    cp ../terraform.tfvars terraform.tfvars

    terraform init
    terraform plan -generate-config-out=generated.tf
    ```
    **Expected:** the plan fails with six errors. That is the correct result. Abridged:

    ```
    │ Generating configuration during import is currently experimental...
    │
    │ Error: "" is not a valid CIDR block: invalid CIDR address:
    │   with aws_route_table.public_rt, on generated.tf line 3
    │
    │ Error: Conflicting configuration arguments
    │   with aws_subnet.subnet-a, on generated.tf line 2
    │   "availability_zone": conflicts with availability_zone_id
    │
    │ Error: enable_lni_at_device_index must not be zero, got 0
    │   with aws_subnet.subnet-a, on generated.tf line 7
    │
    │ Error: Missing required argument
    │   with aws_vpc.custom-vpc, on generated.tf line 10
    │   "ipv6_netmask_length": all of `ipv6_ipam_pool_id,ipv6_netmask_length` must be specified
    │
    │ Error: Missing required argument
    │   with aws_subnet.subnet-a, on generated.tf line 15
    │   "map_customer_owned_ip_on_launch": all of
    │   `customer_owned_ipv4_pool,map_customer_owned_ip_on_launch,outpost_arn` must be specified
    ```

    Every error is generation writing an argument it should have left out: an empty value where the
    attribute was never set, both halves of a conflicting pair, or one member of a group the
    provider requires to be set together.

    > **Why do the errors cite line numbers in a file that failed to plan?** Terraform writes the
    > file first and validates it second. The plan failed, but `generated.tf` is complete and on
    > disk.

7. **Compare the generated config against the cleaned one**

    `../network.tf` contains the same subnet after cleanup. Put the two side by side:

    ```bash
    sed -n '/^resource "aws_subnet"/,/^}/p' generated.tf  > /tmp/subnet-generated.tf
    sed -n '/^resource "aws_subnet"/,/^}/p' ../network.tf > /tmp/subnet-clean.tf

    wc -l /tmp/subnet-generated.tf /tmp/subnet-clean.tf
    diff /tmp/subnet-clean.tf /tmp/subnet-generated.tf
    ```

    Every `>` line in the diff is something you would have deleted or rewritten by hand. Notice
    `availability_zone` and `availability_zone_id` both present, `enable_lni_at_device_index = 0`,
    the computed `tags_all`, and `vpc_id` as a hardcoded `vpc-0abc…` string rather than a reference.

    The cleaned version keeps four arguments, and each takes its value from a different place:

    | Cleaned (`network.tf`) | Source | Why |
    |---|---|---|
    | `vpc_id = aws_vpc.custom-vpc.id` | **resource reference** | Terraform now knows the subnet depends on the VPC. The generated file carried no dependency information at all. |
    | `cidr_block = var.public_subnet_cidr` | **variable** | Defined once instead of a hardcoded `"192.168.0.0/24"`. |
    | `availability_zone = data.aws_subnet.imported.availability_zone` | **data source** | Read from the real subnet at plan time, which sidesteps the `availability_zone_id` conflict. |
    | `map_public_ip_on_launch = true` | **literal** | A deliberate setting. Literals are fine for real decisions. |

    > **Nothing in the generated file is wrong.** It is an accurate snapshot of what exists right
    > now. Read-only attributes like `arn` and `owner_id` are correctly omitted. What it lacks is
    > references, variables, and the judgement about which arguments matter.

    Leave `generated.tf` in place — the optional Challenge at the end of this lab uses it.

---

## Task 4: Execute the Import (15 min)

8. **Write the four security group import blocks**

    ```bash
    cd ~/Advanced_Terraform/lab2/import
    cat imports.tf
    ```

    Five import blocks ship complete — the VPC stack. The security group and its three rules are
    left for you. Each block needs a `to` (the Terraform resource address) and an `id` (the AWS
    identifier, already in your tfvars as a variable).

    The four addresses, and the variable holding each ID:

    | Resource address | ID variable |
    |---|---|
    | `aws_security_group.allow-http-ssh` | `var.security_group_id` |
    | `aws_vpc_security_group_ingress_rule.allow-http-ipv4` | `var.sg_rule_http_id` |
    | `aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` | `var.sg_rule_ssh_id` |
    | `aws_vpc_security_group_egress_rule.allow-all-outbound` | `var.sg_rule_egress_id` |

    Follow the shape of the five blocks already in the file. If you get stuck, a complete set is in
    `generate-config-demo/imports.tf`.

    ```bash
    terraform fmt
    terraform validate
    ```
    **Expected:**

    ```
    Success! The configuration is valid.
    ```

    > **Why import blocks rather than the `terraform import` command?** Import blocks live in your
    > `.tf` files, get version-controlled, get reviewed, and run as part of the normal
    > `plan`/`apply` cycle. The legacy `terraform import <addr> <id>` command is one-shot and leaves
    > no record.

9. **Notice the compound ID for the route table association**

    Look at the fifth block you did not have to write:

    ```hcl
    import {
      to = aws_route_table_association.public_subnet_a
      id = "${var.subnet_id}/${var.route_table_id}"
    }
    ```
    Some AWS resources have no single identifier of their own and are addressed by a composite of
    their parents. Route table associations use `<subnet-id>/<route-table-id>`. The provider
    documentation gives the import format for every resource.

10. **Review the cleaned configuration**

    ```bash
    cat network.tf
    cat security-group.tf
    ```

    These declare the same nine addresses your import blocks name. After the import, every line
    should evaluate to "matches reality."

11. **Plan the import**

    ```bash
    terraform plan
    ```
    **Expected:**

    ```
    Plan: 9 to import, 0 to add, 0 to change, 0 to destroy.
    ```

    Notice the count is **9 to import** and **0 to add**. If you see something like "5 to import, 4
    to add", one or more of your Step 8 blocks is missing or has the wrong address — Terraform has
    found configuration for a resource it has no instruction to import, so it plans to create a
    second one. Fix `imports.tf` before applying.

    > **If the plan shows changes:** the configuration does not match what is deployed. Compare it
    > against the actual AWS resource and either correct the config or document the drift.

12. **Apply the import**

    ```bash
    terraform apply
    ```
    Type `yes`. Terraform imports all 9 resources in dependency order:

    ```
    aws_vpc.custom-vpc: Importing... [id=vpc-...]
    aws_vpc.custom-vpc: Import complete [id=vpc-...]
    aws_subnet.subnet-a: Importing... [id=subnet-...]
    ...
    aws_vpc_security_group_egress_rule.allow-all-outbound: Import complete

    Apply complete! Resources: 9 imported, 0 added, 0 changed, 0 destroyed.
    ```

13. **Verify a clean plan**

    ```bash
    terraform plan
    ```
    **Expected:**

    ```
    No changes. Your infrastructure matches the configuration.
    ```

    Terraform now manages nine previously unmanaged resources with zero drift.

14. **List the managed resources**

    ```bash
    terraform state list
    ```
    ```
    aws_internet_gateway.igw
    aws_route_table.public_rt
    aws_route_table_association.public_subnet_a
    aws_security_group.allow-http-ssh
    aws_subnet.subnet-a
    aws_vpc.custom-vpc
    aws_vpc_security_group_egress_rule.allow-all-outbound
    aws_vpc_security_group_ingress_rule.allow-http-ipv4
    aws_vpc_security_group_ingress_rule.allow-ssh-ipv4
    ```

    Output is alphabetical by address — that is how `state list` always sorts.

---

## Task 5: Protect Critical Resources (5 min)

15. **Add `prevent_destroy` to the VPC and the security group**

    Edit `network.tf` and `security-group.tf`. Each already has a `lifecycle` block with the
    `prevent_destroy` line commented out. Uncomment it in both, leaving the `lifecycle {` and `}`
    lines alone:

    ```hcl
    lifecycle {
      prevent_destroy = true
    }
    ```

    > **Why protect the security group too?** Once workloads attach to a security group, deleting it
    > severs connectivity for every instance using it. `prevent_destroy` makes accidental removal a
    > hard stop.

16. **Verify the lifecycle change loads cleanly**

    ```bash
    terraform plan
    ```
    **Expected:**

    ```
    No changes. Your infrastructure matches the configuration.
    ```

    > **Why no diff, and why no `terraform apply`?** `lifecycle` blocks are **plan-time
    > meta-arguments**, not resource attributes. Terraform reads them client-side on every plan, but
    > they are not stored in state and they change nothing in AWS. Uncommenting one produces zero
    > diff and there is nothing to apply. The protection is active the moment the config parses.

17. **Test the protection**

    ```bash
    terraform plan -destroy
    ```
    **Expected:**

    ```
    Error: Instance cannot be destroyed
      on network.tf line ...:
       ... aws_vpc.custom-vpc ...

    Resource aws_vpc.custom-vpc has lifecycle.prevent_destroy set, but the
    plan calls for this resource to be destroyed.
    ```

    > **What `prevent_destroy` does not protect against.** It blocks any plan whose action on the
    > resource is `destroy`, for as long as the `lifecycle` block stays in the configuration. It does
    > not stop someone removing the resource block entirely and re-applying, deleting the resource
    > in the console, or an account-level force such as an SCP change. Real production protection
    > layers this with IAM policies denying `*Delete*` actions, organisation SCPs, and CloudTrail
    > alarms on delete events.

---

## Challenge: Clean the Generated Config Yourself (optional, ~10 min)

Everything this needs is already on disk. It is optional — if you are short on time, go straight to
Task 6 and clean up.

In Task 3 you read the generated configuration and compared one resource against the cleaned
version. This is the same job for real: take the file `-generate-config-out` wrote and make it
plan cleanly.

**The work.** In `generate-config-demo/`, edit `generated.tf` until `terraform plan` reports an
import with no changes. The demo folder has no `network.tf` or `security-group.tf`, so your file is
the only configuration there and nothing collides with it.

**Success condition:**

```bash
cd ~/Advanced_Terraform/lab2/import/generate-config-demo
terraform plan
```

```
Plan: 9 to import, 0 to add, 0 to change, 0 to destroy.
```

Four things to work out for yourself:

- Which arguments to delete. Most of what generation wrote is either a computed attribute or an
  empty value standing in for one that was never set.
- Which of the two conflicting availability-zone arguments to keep.
- How to turn the hardcoded `vpc_id = "vpc-0abc…"` strings into references, so the file describes
  the dependencies rather than restating today's IDs.
- Why `tags_all` must go, and what `tags` should say instead.

**Do not run `terraform apply` here.** The resources are already managed by the state you imported
into in Task 4. Applying would give two states the same nine resources, which is the dual-management
hazard this lab opens by warning about.

When you are finished:

```bash
rm generated.tf /tmp/subnet-generated.tf /tmp/subnet-clean.tf
cd ~/Advanced_Terraform/lab2/import
```

---

## Task 6: Cleanup (5 min)

18. **Remove `prevent_destroy` so cleanup can proceed**

    Edit `network.tf` and `security-group.tf` and comment the `prevent_destroy` lines out again.
    Production would not do this casually.

19. **Destroy the imported infrastructure**

    ```bash
    cd ~/Advanced_Terraform/lab2/import
    terraform destroy
    ```
    This destroys the nine imported resources. **Your state bucket is untouched** — it was never
    imported into this state.

20. **Remove the workspace and the standalone stack's local state**

    ```bash
    terraform workspace select default
    terraform workspace delete dev
    ```

    The resources are gone from AWS, but `lab2/existing-stack/terraform.tfstate` still believes it
    owns them. Clear it:

    ```bash
    cd ~/Advanced_Terraform/lab2/existing-stack
    terraform state rm $(terraform state list)
    rm -rf .terraform .terraform.lock.hcl terraform.tfstate.backup
    ```

    > **Do not run `terraform destroy` from `existing-stack/`.** The AWS resources are already gone,
    > so destroy fails when Terraform tries to refresh state. `state rm` is the right tool.

    > **Does deleting the dev workspace affect Labs 3 and 4?** No. Every lab keeps its state under
    > its own key in the shared bucket — Lab 2 uses `imported/`, Lab 3 uses `pipeline/`, Lab 4 uses
    > `observability/`. Neither Lab 3 nor Lab 4 reads anything Lab 2 produced.

---

## Lab Completion Checklist

- [ ] Deployed the standalone VPC + SG stack
- [ ] Captured 8 resource IDs plus the state bucket name and its region
- [ ] Configured `lab2/import/terraform.tfvars`
- [ ] Initialized the backend with `-backend-config="bucket=..." -backend-config="region=..."`
- [ ] Created and selected the `dev` workspace
- [ ] Ran `-generate-config-out` and diffed its output against the cleaned `network.tf`
- [ ] Wrote the four security group import blocks
- [ ] Ran `terraform plan` — saw "9 to import, 0 to add, 0 to change"
- [ ] Ran `terraform apply` — imported all 9 resources
- [ ] Verified a clean plan (No changes)
- [ ] Added `prevent_destroy` to the VPC and security group, and tested it
- [ ] Cleaned up (state bucket untouched — never imported)

---

## Troubleshooting

### Plan says "to add" instead of "to import"

An import block is missing or names the wrong address. Terraform found configuration for a resource
it has no instruction to import, so it plans to create a new one. Compare the `to` addresses in
`imports.tf` against `terraform state list` output in the resource table above.

### "Resource already exists" error

The resource may already be in state from a previous attempt:

```bash
terraform state list
terraform state rm <resource_address>
```

### Plan shows changes after import

Your configuration does not match reality. Compare them directly:

```bash
terraform state show aws_vpc.custom-vpc
aws ec2 describe-vpcs --vpc-ids <id>
```
Adjust either the config or the resource until they agree, then re-plan.

### Compound ID error on the route table association

```
Error: ID "rtbassoc-..." doesn't match expected format "<subnet-id>/<route-table-id>"
```

You used the AWS-side `rtbassoc-` ID. The import format is the compound
`<subnet-id>/<route-table-id>`.

### Cannot create dev workspace ("workspace already exists")

That is fine — `terraform workspace select dev` is the next command anyway.

---

## Next Steps

In **Lab 3: Pipeline Operations**, you will build a CI/CD pipeline that takes a Terraform config
and applies it to staging and prod through CodePipeline with manual approval gates. Existing
infrastructure lives in dev (this lab); pipeline-managed environments land in staging and prod.

---

## Additional Resources

| Resource | URL |
|---|---|
| Import Blocks | https://developer.hashicorp.com/terraform/language/import |
| Config Generation | https://developer.hashicorp.com/terraform/language/import/generating-configuration |
| Lifecycle Meta-Arguments | https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle |
| `aws_route_table_association` (compound ID) | https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association |
| `aws_vpc_security_group_ingress_rule` | https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule |
| Terraform workspaces | https://developer.hashicorp.com/terraform/cli/workspaces |
