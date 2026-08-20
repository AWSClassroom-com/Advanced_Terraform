# Lab 2: Import Day 1-2 Infrastructure into Remote State

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Chapter** | Importing Existing Infrastructure into Terraform |
| **Duration** | 60 minutes |
| **Difficulty** | Advanced |
| **Version** | 3.2 (9-resource import, S3 intentionally excluded) |
| **Prerequisites** | Lab 1 completed (workspaces, S3 backend with `use_lockfile`). A pre-existing VPC + `allow-http-ssh` SG is helpful but **not required** — the lab provides a fallback `lab2/day1-vpc-lean/` stack you can deploy in Part A if you don't have one. |
| **Terraform** | >= 1.10.0 |
| **AWS Provider** | `~> 6.0` |
| **Lab Files** | [github.com/AWSClassroom-com/Advanced_Terraform](https://github.com/AWSClassroom-com/Advanced_Terraform) → `lab2/import/`. The `lab2/day1-vpc-lean/` directory is in the same repo as a fallback for students who don't already have a VPC running. |
---

## Lab Overview

### Narrative

In Day 1-2 Lab 3, you deployed a VPC stack and an `allow-http-ssh` security group. That state lived in the same `~/terraform/aws/my-app/` directory through Day 2 — and after the Lab 6 modularization, the resources are at addresses like `module.vpc.aws_vpc.custom-vpc`.

Today you'll practice the **import workflow** by bringing those same resources into a **separate, fresh Terraform configuration** — under your **dev workspace** (the workspace pattern from Lab 1). This simulates the real-world scenario where you discover existing infrastructure and want to manage it with a fresh, well-organized config rather than the original implementation.

> **Why no S3 bucket?** The S3 state bucket is **already** managed by `lab1/state-infra`'s state. Importing it into a second state would create dual-management — both states would think they own the bucket, and the next `terraform apply` from either side could break the other. Plus, **you generally don't experiment with state buckets in import labs** — destroying or accidentally drifting your state bucket means losing access to all your Day 3 work. We import the VPC + SG stack only.

### Learning Objectives

By the end of this lab, you will:

- **Reuse Lab 1's workspace pattern** to import resources into the **dev** workspace specifically
- **Write import blocks** (Terraform 1.5+) declaring 9 resources to bring under management
- **Experience config generation** and understand its limitations (the cleanup pattern)
- **Import 9 resources** following dependency order (5 VPC stack + SG + 3 modern rule resources)
- **Achieve a clean plan** ("No changes") as proof of successful import
- **Add lifecycle protection** to critical resources (`prevent_destroy`)

---

## Cost Reality Check

This lab imports resources that **already exist** from Day 1-2. **No new infrastructure is deployed during the import itself** — Terraform just gains awareness of what's already there. Cost during the lab: $0/hour beyond what Days 1-2 are already running.

If you don't have a Day 1-2 VPC available (or yours was destroyed at end of class), use the `lab2/day1-vpc-lean/` directory in this repo: it's the same Day 1-2 `aws/vpc/` config minus the NAT gateway, costing ~$0/hour to deploy fresh. Import works identically against either version.

---

## Resources to Import (9 total)

| # | Resource address | Source (Day 1-2) | Notes |
|---|------------------|------------------|-------|
| 1 | `aws_vpc.custom-vpc` | Lab 3 Task 2 | VPC must be first (others depend on it) |
| 2 | `aws_subnet.subnet-a` | Lab 3 Task 2 | Pre-Lab 4 single-subnet form |
| 3 | `aws_internet_gateway.igw` | Lab 3 Task 2 | |
| 4 | `aws_route_table.public_rt` | Lab 3 Task 2 | |
| 5 | `aws_route_table_association.public_subnet_a` | Lab 3 Task 2 | **Compound import ID** `<subnet>/<rt>` |
| 6 | `aws_security_group.allow-http-ssh` | Lab 3 Task 3 | |
| 7 | `aws_vpc_security_group_ingress_rule.allow-http-ipv4` | Lab 3 Task 3 | Modern rule resource |
| 8 | `aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` | Lab 3 Task 3 | Modern rule resource |
| 9 | `aws_vpc_security_group_egress_rule.allow-all-outbound` | Lab 3 Task 3 | Modern rule resource |

The VPC stack imports in dependency order (VPC → subnet → IGW → route table → RT association). The security group must import before its rules (rules reference the SG ID).

**What's intentionally NOT here:**
- **NAT Gateway** — Day 1-2 deploys it (Lab 3 Task 2) but we exclude it from imports because it's expensive (~$1/day) and not needed for this lab's lesson.
- **S3 state bucket** — already managed by `lab1/state-infra`. See "Why no S3?" in the narrative above.
- **ALB / ALB SG / ASG / launch template** — Lab 5 territory; not relevant to the import lesson.
- **`for_each` subnets / private subnets** — Lab 4+ refactor. The 9-resource scope keeps the import addresses clean.

---

## Task 1: Get Your 8 Resource IDs (5–10 min)

Lab 2 imports 9 resources that already exist in AWS. Before you can import them, you need their AWS IDs (`vpc-…`, `subnet-…`, `sg-…`, etc.). You have two paths to get those IDs — **pick the one that matches your environment and skip the other.** Both paths end at the same place: the 8 resource IDs plus your state bucket name, ready to paste into Task 2.

> **Option A** — *5 min* — your Day 1-2 VPC and `userxx-allow-http-ssh` security group are still deployed.
>
> **Option B** — *10 min* — you don't have Day 1-2 resources running. Deploy the lean VPC stack provided in this repo, then read its outputs.
>
> **If your AWS account was provisioned fresh for Day 3, use Option B.** There are no Day 1-2 VPC or security-group resources to find, and the only state bucket in the account is the one Lab 1 created.

> **Before you start — set two env vars in your shell.** The CLI commands below filter on your IAM username and your assigned deployment region. Don't rely on `$USER` from the shell — on lab VMs that's typically `ec2-user`/`cloudshell-user`, not your IAM username. Set both explicitly:
>
> ```bash
> export STUDENT="user07"          # your IAM username from Day 1-2 (NOT your shell $USER)
> export DEPLOY_REGION="us-east-2" # the region your Day 1-2 VPC lives in (your instructor will tell you which)
> ```
>
> Re-run these `export`s in any new terminal you open. They persist for the rest of Task 1 and are also useful in Task 2.

### Option A — Using your existing Day 1-2 resources

1. **Verify the stack still exists**

    ```bash
    aws s3 ls | grep "${STUDENT}-terraform-state"
    aws ec2 describe-vpcs --region "$DEPLOY_REGION" \
        --filters "Name=tag:Name,Values=*${STUDENT}*" \
        --query 'Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,Tags:Tags}' \
        --output table
    ```
    You should see your `${STUDENT}-terraform-state-…` bucket from Lab 1 (output of `aws s3 ls`) and a VPC tagged with your username. **Note both the state bucket name AND which region it lives in.** You'll pass both at `terraform init` time in Task 2.

2. **Capture the VPC stack IDs (vpc, subnet, IGW, route table)**

    ```bash
    VPC_ID=$(aws ec2 describe-vpcs --region "$DEPLOY_REGION" \
        --filters "Name=tag:Name,Values=*${STUDENT}*" \
        --query 'Vpcs[0].VpcId' --output text)
    echo "VPC: $VPC_ID"

    aws ec2 describe-subnets --region "$DEPLOY_REGION" \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[].{Id:SubnetId,CIDR:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}' \
        --output table

    aws ec2 describe-internet-gateways --region "$DEPLOY_REGION" \
        --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
        --query 'InternetGateways[].InternetGatewayId' --output text

    aws ec2 describe-route-tables --region "$DEPLOY_REGION" \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'RouteTables[].{Id:RouteTableId,Name:Tags[?Key==`Name`]|[0].Value}' \
        --output table
    ```
    Save: `vpc_id`, `subnet_id` (the public subnet), `internet_gateway_id`, `route_table_id` (the public route table — name ends in `public-route-table`; the VPC's main RT also appears in this list but has no Name tag, ignore it).

3. **Capture the SG + 3 rule IDs**

    ```bash
    SG_ID=$(aws ec2 describe-security-groups --region "$DEPLOY_REGION" \
        --filters "Name=group-name,Values=${STUDENT}-allow-http-ssh" \
        --query 'SecurityGroups[0].GroupId' --output text)
    echo "SG: $SG_ID"

    aws ec2 describe-security-group-rules --region "$DEPLOY_REGION" \
        --filters "Name=group-id,Values=${SG_ID}" \
        --query 'SecurityGroupRules[].{Id:SecurityGroupRuleId,Port:FromPort,Egress:IsEgress}' \
        --output table
    ```
    Save: `security_group_id`, `sg_rule_http_id` (`Port=80, Egress=false`), `sg_rule_ssh_id` (`Port=22, Egress=false`), `sg_rule_egress_id` (`Egress=true`). **Now skip to Task 2.**

### Option B — Using the lean VPC stack

4. **Deploy the lean VPC**

    ```bash
    cd ~/Advanced_Terraform/lab2/day1-vpc-lean
    cp terraform.tfvars.example terraform.tfvars
    ```

    Edit `terraform.tfvars` and set **both** `account` and `region` — they're both required by the lean stack (`variables.tf` declares `region` with no default, so leaving it empty will fail with "No value for required variable"):

    ```hcl
    account = "userxx"     # your IAM username (e.g., user07) — match $STUDENT from the env-var block above
    region  = "us-east-2"  # your assigned deployment region — match $DEPLOY_REGION from the env-var block above
    ```

    Then:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```
    Review the plan, then type `yes` at the apply prompt. The lean stack matches the Day 1-2 resource names exactly but omits the NAT gateway (~$1/day) — so cost is ~$0/hour.

    > **Why local state?** The lean stack uses **local state by design** (no backend block in `providers.tf`) — it's playing the role of "infrastructure that already exists outside your remote state." That's the exact scenario Lab 2 is built around. Don't move it to S3.

5. **Read all 8 IDs from `terraform output`**

    ```bash
    terraform output
    ```
    The lean stack's `outputs.tf` exposes every ID you need — the output names match the import tfvars keys 1:1:
    - **VPC stack** — `vpc_id`, `subnet_id`, `internet_gateway_id`, `route_table_id`
    - **Security group + rules** — `security_group_id`, `sg_rule_http_id`, `sg_rule_ssh_id`, `sg_rule_egress_id`

    Also capture your **state bucket name and its region**. This is the bucket **Lab 1 created** (`terraform output state_bucket_name` in `lab1/state-infra`). You'll pass both at `terraform init` time in Task 2:

    ```bash
    aws s3 ls | grep "${STUDENT}-terraform-state"
    aws s3api get-bucket-location --bucket "<your-bucket-name>" --query 'LocationConstraint' --output text
    ```
    The bucket name looks like `user07-terraform-state-x8k2m4`. The bucket's region **may or may not match `$DEPLOY_REGION`**. The state bucket and the resources you are importing are independent of each other.

---

## Task 2: Set Up the Import Project (10 min)

6. **Navigate to the import project**

    ```bash
    cd ~/Advanced_Terraform/lab2/import
    ```
7. **Configure variables**

    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

    Edit `terraform.tfvars` with the IDs you captured in Task 1. The `region` field here is the **deployment region** — where your imported VPC and SG actually live in AWS. This is `$DEPLOY_REGION` from the Task 1 env-var block.

    ```hcl
    account = "userxx"      # your IAM username (e.g., user07) — same value as $STUDENT
    region  = "us-east-2"   # DEPLOYMENT region — where the resources you're importing live
                            # (same as $DEPLOY_REGION from Task 1)

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
    > **Two regions, kept separate.** The `region` in this tfvars file configures the AWS *provider* — it tells Terraform "where to find the resources I'm importing." The `region` you'll pass at `terraform init` time (next step) is a different setting — it tells Terraform's *S3 backend* where to find the state bucket. **These can be different.** If your Lab 1 state bucket is in `us-east-2` but your VPC is in `us-west-2`, that's fine and supported — you'd put `us-west-2` here in tfvars and pass `us-east-2` at init time.

8. **Review the backend config**

    Open `providers.tf` — note that the backend block does NOT hard-code the bucket name or region:

    ```hcl
    backend "s3" {
      key          = "imported/terraform.tfstate"   # Workspace prefix env:/dev/ added automatically
      encrypt      = true
      use_lockfile = true                            # Terraform 1.10+ S3 native locking — Day 3 NEW
    }
    ```
    This follows the **same `-backend-config` init pattern Day 1-2 Lab 3 used** — bucket and region are passed at init time rather than hardcoded. That makes the same `providers.tf` file work for any student / any region without edits.

    > **Why a different state key from Lab 1?** Lab 1 uses key `lab1-app/terraform.tfstate`. This lab uses `imported/terraform.tfstate`. **Same bucket, separate state files** — that's the multi-state pattern. Lab 1's app config and Lab 2's imported infrastructure are different concerns and live in different states.

9. **Initialize with backend config and select the dev workspace**

    Pass the **state bucket name** and the **bucket's region** (from Task 1 Step 1 or Step 5, depending on which option you ran):

    ```bash
    terraform init \
        -backend-config="bucket=userXX-terraform-state-SUFFIX" \
        -backend-config="region=us-east-2"
    ```
    Replace the placeholder bucket name with your actual bucket and `us-east-2` with the region your bucket actually lives in (per the `get-bucket-location` command in Task 1 Step 5, or by checking the S3 console).

    > **The region passed here is for the S3 backend** — not where your VPC lives. If you set `region = "us-west-2"` in `terraform.tfvars` (Step 7) but your state bucket is in `us-east-2`, then init takes `us-east-2` here and provider/imports take `us-west-2` from tfvars. The two are independent — getting them confused is the most common source of `BucketRegionError: bucket is in a different region` failures at init time.

    ```bash
    terraform workspace new dev    # creates if missing — error here is fine if it already exists
    terraform workspace select dev
    terraform workspace show
    ```
    **Expected:** `dev`

    > **Why the dev workspace specifically?** The pattern Lab 1 introduced has imports landing in **dev** (where the legacy system actually lives). Staging and prod workspaces will be populated later by Lab 3's CI/CD pipeline applying this same Terraform config to those workspaces — creating equivalent NEW resources, not importing.

---

## Task 3: Review Import Blocks (5 min)

10. **Read the import declarations**

    ```bash
    cat imports.tf
    ```

    You'll see 9 import blocks — 5 for the VPC stack, 4 for the security group + its 3 modern rules. The `to` attribute names a Terraform resource address; the `id` attribute supplies the AWS-side identifier.

    > **Why import blocks beat `terraform import` (the imperative command)?** Import blocks live in your `.tf` files, get version-controlled, get reviewed in PRs, and run as part of `terraform plan`/`apply` — same workflow as everything else. The legacy `terraform import <addr> <id>` command is one-shot and leaves no record. Use blocks for anything that should be reproducible.
11. **Notice the compound ID for route table association**

    In `imports.tf`:

    ```hcl
    import {
      to = aws_route_table_association.public_subnet_a
      id = "${var.subnet_id}/${var.route_table_id}"
    }
    ```
    Some AWS resources have no single AWS-side ID — they need a composite formed from their parents. Route table associations need `<subnet-id>/<route-table-id>`. Same pattern applies to security group rules, IAM policy attachments, etc. The provider docs spell out the import format for each resource.

---

## Task 4: Experience Config Generation (5 min)

Terraform 1.5+ can attempt to **generate config from existing AWS resources**. Let's see what it produces — and why it's only a starting point.

> **Why a subfolder for this task?** `lab2/import/` ships with pre-cleaned `network.tf` and `security-group.tf` for the real import flow in Task 5. If you ran `-generate-config-out` there, terraform would see every resource already has config and exit silently — you'd never see the messy output Chapter 2 warned about. The `generate-config-demo/` subfolder strips those cleaned configs so generate-config has work to do (and fails the way the chapter described). Local state only — the demo never runs `terraform apply`.

12. **Try config generation**

    ```bash
    cd ~/Advanced_Terraform/lab2/import/generate-config-demo

    # Reuse the IDs you already pasted into the parent dir's tfvars
    cp ../terraform.tfvars terraform.tfvars

    terraform init
    terraform plan -generate-config-out=generated.tf
    ```
    **Expected:** the plan fails with six errors, not one. That is the expected result here. Abridged:

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

    Six errors, but only three kinds of problem, all caused by generation emitting arguments it should have omitted:

    | Problem | Errors above | What happened |
    |---|---|---|
    | **Empty value instead of omission** | `"" is not a valid CIDR`, `enable_lni_at_device_index must not be zero` | The attribute was never set on the real resource, so generation wrote the type's empty value (`""`, `0`) instead of leaving the argument out. The provider then validates it as if you set it. |
    | **Both halves of a conflicting pair** | `availability_zone` conflicts with `availability_zone_id` (reported once from each side) | The live resource has both values, so generation wrote both — but the provider only accepts one. |
    | **Part of a required group** | `ipv6_netmask_length`, `map_customer_owned_ip_on_launch` | Generation wrote one argument from a group the provider requires to be set together (or not at all). |

    > **Why do the errors cite line numbers in `generated.tf`?** Because Terraform writes the file first and validates it second. The plan failed, but the generated file is complete and on disk — the next step examines it.

13. **Examine the generated file**

    The file starts with the security group rules, the smallest resources here, which show none of the problems. Print the subnet instead; it has all of them at once:

    ```bash
    sed -n '/^resource "aws_subnet"/,/^}/p' generated.tf
    ```

    Notice the problems Chapter 2 warned about, with the Step 12 errors now visible in context:

    - **Every settable attribute, not just the ones you need** — roughly two dozen arguments where the cleaned version needs four. Most are `null`.
    - **`availability_zone` AND `availability_zone_id`** — the conflicting pair from the plan errors, both emitted because both exist on the live subnet.
    - **`enable_lni_at_device_index = 0`** — the source of the "must not be zero" error. The real subnet never set this attribute; `0` is just the empty value for an integer.
    - **`tags_all`** — a computed merge of the resource's `tags` and the provider's `default_tags`. Computed attributes in the output are expected — cleanup removes them, because they don't belong in config.
    - **Hardcoded IDs, not references** — `vpc_id = "vpc-0abc…"` instead of `aws_vpc.custom-vpc.id`. Terraform doesn't know that ID belongs to the VPC being imported in the same file.

    > **What generation does get right:** read-only attributes like `arn` and `owner_id` are correctly left out — only settable arguments are emitted. The limitations are the ones above: every settable argument, empty values for unset ones, and no references.

14. **Compare the generated version against the cleaned one**

    `../network.tf` contains the same subnet after cleanup: the work `-generate-config-out` leaves for you. Put the two side by side:

    ```bash
    sed -n '/^resource "aws_subnet"/,/^}/p' generated.tf  > /tmp/subnet-generated.tf
    sed -n '/^resource "aws_subnet"/,/^}/p' ../network.tf > /tmp/subnet-clean.tf

    wc -l /tmp/subnet-generated.tf /tmp/subnet-clean.tf
    diff /tmp/subnet-clean.tf /tmp/subnet-generated.tf
    ```

    Every `>` line in the diff is something you would have had to delete or rewrite by hand before the config was usable.

    Removing the extra attributes is the mechanical part. The cleaned version keeps four arguments, and each one takes its value from a different place:

    | Cleaned (`network.tf`) | Source | Why |
    |---|---|---|
    | `vpc_id = aws_vpc.custom-vpc.id` | **resource reference** | Terraform now knows the subnet depends on the VPC. The generated file had no dependency information at all. |
    | `cidr_block = var.public_subnet_cidr` | **variable** | Defined once in `variables.tf` / `terraform.tfvars` instead of the hardcoded `"192.168.0.0/24"`. |
    | `availability_zone = data.aws_subnet.imported.availability_zone` | **data source** | Read from the real subnet at plan time — and avoids the `availability_zone_id` conflict entirely. |
    | `map_public_ip_on_launch = true` | **literal** | A deliberate setting. Literals are fine for values that are real decisions. |

    The tags follow the same pattern: generated hardcodes `Name = "user07-public-subnet-a"`; the cleaned version uses `Name = "${var.account}-public-subnet-a"`, so the same file works for every student.

    > **Note:** nothing in the generated file is wrong. It is an accurate snapshot of what exists right now. Cleanup turns that snapshot into configuration: references for dependencies, variables for reuse, and no computed attributes.

15. **Clean up the demo + return to the real import dir**

    ```bash
    rm generated.tf /tmp/subnet-generated.tf /tmp/subnet-clean.tf
    cd ~/Advanced_Terraform/lab2/import
    ```

    > **Key takeaway:** `-generate-config-out` is a starting point for cleanup, not a finished file. For this lab, we did the cleanup work for you in `network.tf` and `security-group.tf` (which is why the demo subfolder above doesn't have them). The cleanup pattern: keep only the attributes you actually set, drop the read-only ones the provider fills in (`tags_all`), resolve conflicting pairs like `availability_zone`/`availability_zone_id` down to one, and replace hardcoded IDs with resource references.

---

## Task 5: Execute the Import (15 min)

16. **Review the cleaned configuration**

    ```bash
    ls -la *.tf
    cat network.tf
    cat security-group.tf
    ```

    These match the import block addresses 1-for-1. After `terraform apply`, every line should evaluate to "matches reality."

17. **Plan the import**

    ```bash
    terraform plan
    ```
    **Expected output:**

    ```
    Plan: 9 to import, 0 to add, 0 to change, 0 to destroy.
    ```

    The "0 to change" line is the goal — your config matches the AWS reality.

    > **If the plan shows changes:** the cleaned config doesn't match exactly what's deployed (different CIDR, different tags, missing setting). Compare carefully against the actual AWS resource and either update the config OR document the drift.

18. **Apply the import**

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

19. **Verify clean plan**

    ```bash
    terraform plan
    ```
    **Expected:**

    ```
    No changes. Your infrastructure matches the configuration.
    ```

    This is the moment of truth — Terraform now manages 9 previously-unmanaged resources, with zero drift.

20. **List managed resources**

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

    Output is alphabetical by address — that's how `state list` always sorts.

---

## Task 6: Protect Critical Resources (10 min)

21. **Add `prevent_destroy` to the VPC**

    Edit `network.tf`. In the `lifecycle` block on `aws_vpc.custom-vpc`, uncomment the `prevent_destroy` line (leave the `lifecycle {` and `}` lines alone — they're already active):

    ```hcl
    resource "aws_vpc" "custom-vpc" {
      # ... existing config ...

      lifecycle {
        prevent_destroy = true
      }
    }
    ```
22. **Add `prevent_destroy` to the security group**

    Edit `security-group.tf`. Same one-line change: uncomment `prevent_destroy` inside the `lifecycle` block on `aws_security_group.allow-http-ssh`:

    ```hcl
    resource "aws_security_group" "allow-http-ssh" {
      # ... existing config ...

      lifecycle {
        prevent_destroy = true
      }
    }
    ```

    > **Why protect the SG?** Once production workloads attach to a security group, deleting it can sever connectivity for every running instance. `prevent_destroy` makes accidental removal a hard stop. (For the **state bucket** itself — which we deliberately did NOT import — the same principle applies even more strongly. That's why the state bucket stays under `lab1/state-infra`'s management with its own protections.)
23. **Verify the lifecycle change loads cleanly**

    ```bash
    terraform plan
    ```
    **Expected:** `No changes. Your infrastructure matches the configuration.`

    > **Why no diff, and why no `terraform apply`?** `lifecycle` blocks (`prevent_destroy`, `ignore_changes`, `create_before_destroy`, `replace_triggered_by`) are **plan-time meta-arguments**, not resource attributes. Terraform reads them client-side every time it plans, but they aren't stored in state and they don't change anything on AWS. So uncommenting the `lifecycle` block produces zero diff and there's nothing to apply — the protection is active the moment the config parses. Step 24 is what actually proves it's working.
24. **Test the protection**

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

    > **What `prevent_destroy` actually protects against:** It blocks any plan whose action on this resource is `destroy` while the `lifecycle` block remains in the configuration. It does **not** protect against:
    > - Removing the resource block entirely (then re-applying)
    > - Out-of-band deletion (someone deleting via the AWS Console)
    > - Account-level forces (SCPs, role boundary changes)
    >
    > For real production protection, layer with: AWS resource tags + IAM policies that deny `*Delete*` actions, organisation-level SCPs, CloudTrail alarms on delete events.
    ---

## Task 7: Cleanup (5 min)

25. **Remove `prevent_destroy` so cleanup can proceed**

    For this lab cleanup only — production wouldn't do this casually.

    Edit `network.tf` and `security-group.tf` — comment out the `lifecycle { prevent_destroy = true }` blocks again.

26. **Clean up imported infrastructure**

    If you deployed the lean VPC in Task 1 Option B, destroy from `lab2/import/`:

    ```bash
    cd ~/Advanced_Terraform/lab2/import
    terraform destroy
    ```
    This destroys the 9 imported resources (VPC + subnet + IGW + RT + RT assoc + SG + 3 rules). **Your state bucket is untouched** — it was never imported into this state, so `terraform destroy` from this directory has no effect on it.

    > **If you're using your existing Day 1-2 stack** (not the lean VPC), think before running destroy: this destroys the actual VPC + SG that Day 1-2 deployed. If you want to keep them for Day 4 / future labs, instead run `terraform state rm <addr>` to remove them from this lab's state without affecting AWS.

27. **Remove the lab2/import workspace**

    ```bash
    # You're in ~/Advanced_Terraform/lab2/import/ on the dev workspace, after destroy completes.
    terraform workspace select default
    terraform workspace delete dev
    ```

    > **Does this affect Labs 3 and 4?** No. Every lab keeps its state under its own key in the shared bucket — Lab 2 uses `imported/`, Lab 3 uses `pipeline/`, Lab 4 uses `observability/`. Deleting the `dev` workspace here removes Lab 2's state file only. The bucket and the other labs' state are untouched, and neither Lab 3 nor Lab 4 reads anything Lab 2 produced.
    > **If you used Option B (lean VPC)**, also clean up the lean stack's local state. Step 26's `terraform destroy` (from `lab2/import/`) already removed the actual AWS resources, but `lab2/day1-vpc-lean/terraform.tfstate` still thinks it owns them — dangling references. The cleanest way to clear that:
    >
    > ```bash
    > cd ~/Advanced_Terraform/lab2/day1-vpc-lean
    > # Drop every resource from the lean stack's state (resources are already gone from AWS).
    > terraform state rm $(terraform state list)
    > # Optional: also remove the local Terraform working dir.
    > rm -rf .terraform .terraform.lock.hcl terraform.tfstate.backup
    > ```
    >
    > **Don't run `terraform destroy` from `lab2/day1-vpc-lean/`** — the AWS resources are already gone, so destroy would fail when terraform tries to refresh state. State-rm is the right tool.

---

## Lab Completion Checklist

- [ ] Verified Day 1-2 VPC + SG are running (or deployed lean version)
- [ ] Captured 8 resource IDs (4 VPC + SG + 3 rule IDs) + state bucket name
- [ ] Configured `lab2/import/terraform.tfvars` with the IDs
- [ ] Initialized backend with `-backend-config="bucket=..." -backend-config="region=..."`
- [ ] Created and selected the `dev` workspace
- [ ] Reviewed the 9 import blocks in `imports.tf`
- [ ] Tried `-generate-config-out` and diffed its output against the cleaned `network.tf`
- [ ] Ran `terraform plan` — saw "9 to import, 0 to change"
- [ ] Ran `terraform apply` — successfully imported all 9 resources
- [ ] Verified clean plan (No changes)
- [ ] Added `prevent_destroy` to the VPC and security group
- [ ] Tested protection with `terraform plan -destroy`
- [ ] Cleaned up (state bucket untouched — never imported)

---

## Troubleshooting

### "Resource already exists" Error

Resource may already be in state from a previous attempt:

```bash
terraform state list
terraform state rm <resource_address>
```
### Plan shows changes after import

Your config doesn't match reality. Common causes:
- Different CIDR than what's tagged in tfvars
- Tags exist on the resource that aren't in config (or vice versa)
- AMI / availability zone differs

Compare carefully:

```bash
terraform state show aws_vpc.custom-vpc
aws ec2 describe-vpcs --vpc-ids <id>
```
Adjust either config or the actual resource until they agree, then re-plan.

### Compound ID error on route table association

```
Error: ID "rtbassoc-..." doesn't match expected format "<subnet-id>/<route-table-id>"
```

You used the AWS-side `aws_route_table_association.id` (which starts with `rtbassoc-`). The import format is the COMPOUND ID — `<subnet-id>/<route-table-id>`. Update `imports.tf` accordingly.
### Cannot create dev workspace ("workspace already exists")

That's fine — `terraform workspace select dev` is the next command anyway. Move on.

### State bucket import fails with permission denied

Your IAM user needs `s3:ListBucket`, `s3:GetBucketVersioning`, `s3:GetBucketEncryption`, `s3:GetBucketAcl`, `s3:GetBucketPublicAccessBlock`, `s3:GetBucketOwnershipControls` on the bucket. The lab IAM policy should already include these — flag the instructor if not.

---

## Cost Considerations

Importing existing resources costs **$0** — Terraform just reads from AWS and writes to its state file. The underlying resources continue to cost whatever they were already costing.

| Resource | Cost while running |
|---|---|
| VPC, subnet, IGW, RT, RT assoc | Free |
| Security group + 3 rules | Free |
| **If you deployed the lean VPC fresh in Task 1** | $0/hour (no NAT GW, no EC2) |

---

## Further Reading: bulk import tooling

For larger import projects (dozens or hundreds of resources across an account or region), the manual `import` block pattern from this lab gets tedious. The community-maintained tools below auto-generate import blocks and starter configuration:

- **[Terraformer](https://github.com/GoogleCloudPlatform/terraformer)** — generates `.tf` and `.tfstate` for existing infrastructure across AWS, GCP, Azure, and 30+ providers. Day 2 Chapter 4 mentioned this.
- **[Terracognita](https://github.com/cycloidio/terracognita)** — similar approach with a focus on infrastructure-as-code adoption for existing accounts.
- **[Former2](https://github.com/iann0036/former2)** — generates Terraform (and CloudFormation/CDK) from existing AWS resources via a browser-based scanner.

Expect the same cleanup work afterwards as you saw with `-generate-config-out` in Task 4: every generated config has computed-only fields, conflicting attributes, and `tags_all` blocks that need to be stripped before the plan will come back clean.

---

## Knowledge Check

**Q1.** Why import into the **dev workspace** specifically rather than the default workspace or a separate state path?
*A: To match the workspace convention Lab 1 established (dev/staging/prod). The legacy resources actually live in the dev environment of your platform setup. Lab 3 will then have CI/CD apply this same configuration to staging and prod workspaces, creating equivalent fresh resources there — that's lift-and-shift.*

**Q2.** The original `aws_route_table_association` resource has an AWS-side ID like `rtbassoc-0abcdef1234`. Why does the `import` block use `${var.subnet_id}/${var.route_table_id}` instead?
*A: Some AWS resources have no single primary identifier and Terraform uses a composite of their parents to import them. For route table associations, the import format is `<subnet-id>/<route-table-id>`. The `rtbassoc-` ID is what AWS returns AFTER the resource exists; the COMPOUND ID is what Terraform uses to find it.*

**Q3.** Why did this lab deliberately NOT import the S3 state bucket?
*A: Two reasons. (1) The bucket is already managed by `lab1/state-infra`'s state, and importing it into a second state would create dual-management, where two states each think they own the resource and either could break the other. (2) State buckets hold the state files for every Terraform project you've built — destroying one (or accidentally drifting it) means losing access to all of that work. Even with `prevent_destroy`, you generally don't experiment with state buckets in import labs. The right move is to leave the bucket under `lab1/state-infra`'s management and never touch it from a secondary state.*

---

## Next Steps

In **Lab 3: Pipeline Operations**, you'll build a CI/CD pipeline that takes a Terraform config (similar to this one) and **applies it to staging and prod workspaces** through CodePipeline with manual approval gates. The lift-and-shift pattern: legacy lives in dev (this lab), pipeline-managed clones land in staging and prod (next lab).

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
