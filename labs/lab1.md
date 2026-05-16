# Lab 1: Multi-Environment State Strategy

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Module** | Enterprise Workspaces & Cross-Environment Dependencies |
| **Duration** | 60 minutes |
| **Difficulty** | Advanced |
| **Version** | 4.2 |
| **Prerequisites** | Workspace concepts from Day 2 Chapter 7 (lecture); Terraform CLI installed. Days 1-2 hands-on labs are **not** required — this lab creates its own S3 state bucket. |
| **Terraform** | >= 1.10.0 |
| **Lab Files** | [github.com/AWSClassroom-com/Advanced_Terraform](https://github.com/AWSClassroom-com/Advanced_Terraform) → `lab1/state-infra/`, `lab1/networking/`, `lab1/directories/` |
---

## Lab Overview

### Narrative

After completing Days 1 and 2, every Terraform project in your organization can use remote state in S3 with encryption, versioning, and native locking. The team can migrate state and refactor configurations using `moved` blocks.

Now your platform team faces a strategic challenge: **how should you organize state across 40 microservices and 3 environments?**

Three teams have different approaches:

- **Payments team** — uses separate directories (`payments-dev/`, `payments-staging/`, `payments-prod/`). Safe, but lots of code duplication across three near-identical trees.
- **Checkout team** — uses workspaces for everything. Elegant single config, but had a near-miss when an engineer applied to prod thinking they were in dev.
- **Networking team** — maintains a shared VPC that every other team needs to reference. How do other teams get the VPC ID without hardcoding it everywhere?

Your task: Learn Terraform workspaces, implement workspace safety guards, configure cross-state dependencies using `terraform_remote_state`, and develop a decision framework for when to use workspaces versus directories.

### Learning Objectives

By the end of this lab, you will be able to:

- **Use Terraform workspaces** to manage multiple environments from a single configuration
- **Implement workspace safety guards** using preconditions to prevent accidental production applies
- **Configure cross-state dependencies** using `terraform_remote_state` to read outputs from another state file
- **Compare workspaces vs. directory structure** through hands-on experience with both patterns
- **Design state boundaries** based on team ownership and change frequency

---

## Architecture Overview

![Cross-State Dependencies Architecture](../../assets/images/lab1_architecture_overview.png)

*Figure: Networking state exports outputs that the application state reads via `terraform_remote_state`. Each workspace gets its own state path with the `env:/` prefix.*

### Key Concepts

| Concept | Definition |
|---|---|
| **Workspace** | A named instance of Terraform state within a single configuration. Each workspace has its own state file. |
| **terraform.workspace** | Built-in variable that returns the name of the current workspace. Use it to customize resources per environment. |
| **terraform_remote_state** | Data source that reads outputs from another Terraform state file. Enables loose coupling between infrastructure layers. |
| **State Boundary** | The logical division between what resources belong in one state file versus another. Based on team ownership and change frequency. |

---

## Task 1: Workspace Fundamentals — Hands-On Practice (15 min)

In Day 2 Chapter 7, you learned about Terraform workspaces in lecture. Now let's put that knowledge into practice before implementing advanced patterns.

1. **Clone the Lab Repository**

    ```bash
    cd ~
    git clone https://github.com/AWSClassroom-com/Advanced_Terraform.git
    cd Advanced_Terraform/lab1/state-infra
    ```
    2. **Review the Backend Configuration (do not edit yet)**

    Open `providers.tf` and read the backend block. **It's commented out on purpose** — the lab is self-contained:

    ```hcl
    terraform {
      required_version = ">= 1.10.0"

      # PART B: Remote state backend (uncomment AFTER Part A creates the bucket)
      # backend "s3" {
      #   bucket       = "<your-state-bucket-from-terraform-output>"
      #   key          = "lab1-app/terraform.tfstate"
      #   region       = "<your-assigned-region>"   # e.g. us-east-2
      #   encrypt      = true
      #   use_lockfile = true   # S3 native locking (Terraform 1.10+)
      # }

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.0"
        }
      }
    }
    ```

    **Why commented out?** This `lab1/state-infra` directory *creates* the state bucket (`main.tf` defines an `aws_s3_bucket`). You can't point a backend at a bucket that doesn't exist yet — that's the classic chicken-and-egg. So Part A runs with **local state** to create the bucket, captures the bucket name from the output, then optionally migrates to remote in Part B.

    **You do not need a bucket from Day 1-2.** Whether you completed Days 1-2 or skipped straight to Day 3, this lab will create its own bucket. If you already have a Day 1-2 bucket, that's fine — it'll continue to exist independently of the one this lab creates.

    > **About `use_lockfile = true`:** Day 3 uses Terraform 1.10+'s native S3 state locking. No DynamoDB table required. Whatever bucket you end up using just needs `object_lock_enabled = true` (the bucket this lab creates already has that).
    >
    > **Production note:** In production, you'd add a bucket policy with least-privilege IAM (`s3:GetObject`, `s3:PutObject`, `s3:ListBucket` on specific paths). For this lab, we rely on your existing classroom permissions.

3. **Initialize Terraform**

    ```bash
    terraform init
    ```
    4. **Explore the Default Workspace**

    Every Terraform configuration starts with a `default` workspace:

    ```bash

    # List all workspaces (asterisk marks current)
    terraform workspace list
    ```
    **Expected output:**
    ```
    * default
    ```

5. **See How Workspaces Affect State Paths**

    Once a remote S3 backend is configured (you'll switch to one in Step 12), each workspace writes to its own key under the bucket:

    - `default` workspace → `lab1-app/terraform.tfstate`
    - `dev` workspace → `env:/dev/lab1-app/terraform.tfstate`
    - `prod` workspace → `env:/prod/lab1-app/terraform.tfstate`

    The `env:/<workspace>/` prefix is what keeps state files separated per workspace. Right now you're on **local state** (the backend block in `providers.tf` is commented out), so workspace state files are sitting under `terraform.tfstate.d/<workspace>/` on your local disk instead. Same conceptual layout, different storage.

6. **Create Environment Workspaces**

    ```bash

    # Create dev workspace
    terraform workspace new dev

    # Verify you're now in dev
    terraform workspace list
    ```
    **Expected output:**
    ```
      default
    * dev
    ```

    ```bash
    # Create staging and prod workspaces
    terraform workspace new staging
    terraform workspace new prod

    # List all workspaces
    terraform workspace list
    ```
    **Expected output:**
    ```
      default
      dev
    * prod
      staging
    ```

7. **Switch Between Workspaces**

    ```bash

    # Switch to dev
    terraform workspace select dev

    # Verify
    terraform workspace show
    ```
    **Expected output:**
    ```
    dev
    ```

8. **Use terraform.workspace in Configuration**

    Open `variables.tf` and examine how workspace affects configuration:

    ```hcl
    locals {
      # Environment-specific settings based on workspace
      environment_config = {
        dev = {
          instance_type = "t3.micro"
          min_size      = 1
          max_size      = 2
        }
        staging = {
          instance_type = "t3.small"
          min_size      = 2
          max_size      = 4
        }
        prod = {
          instance_type = "t3.medium"
          min_size      = 3
          max_size      = 10
        }
      }

      # Select config for current workspace
      config = local.environment_config[terraform.workspace]
    }
    ```

    **Key insight:** `terraform.workspace` returns `"dev"`, `"staging"`, or `"prod"` depending on which workspace is active. This lets one configuration serve multiple environments.

9. **Verify State Isolation**

    ```bash

    # In dev workspace, check state
    terraform workspace select dev
    terraform state list
    # (empty - nothing deployed yet)

    # Switch to staging
    terraform workspace select staging
    terraform state list
    # (also empty - separate state file)
    ```
    Each workspace has its own state. Resources in `dev` don't appear in `staging`.

    > **Production note:** Workspaces isolate *state*, not *credentials*. The same AWS IAM permissions apply regardless of which workspace you're in. In production environments, teams often use separate AWS accounts per environment (dev/staging/prod) with IAM role assumption, so that workspace selection alone cannot accidentally modify production resources.

10. **Delete a Workspace (Cleanup)**

    ```bash

    # Can't delete current workspace - switch first
    terraform workspace select dev

    # Delete prod (for now - we'll recreate it)
    terraform workspace delete prod
    ```
    **Note:** You can only delete empty workspaces (no resources in state).

---

## Task 2: Workspace Safety Guards (15 min)

The checkout team's near-miss happened because a junior engineer thought they were in `dev` but were actually in `prod`. You'll implement safety guards to prevent this.

11. **Recreate the Prod Workspace**

    ```bash
    terraform workspace new prod
    terraform workspace select dev
    ```
    12. **Configure Your Variables**

    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

    Open `terraform.tfvars` and set both variables to your assigned student ID. Use a **concrete** value like `user07` — the `student_id` variable enforces the regex `^user[0-9]{2}$`, so the literal placeholder `userXX` will fail at plan time:

    ```hcl
    student_id = "user07"  # ← REPLACE 07 with YOUR assigned user number. Must match ^user[0-9]{2}$
    account    = "user07"  # ← Same value as student_id (used as a prefix for Part D's app-config SSM parameter)
    ```

    Leave `region` and `state_bucket_name` commented out for now. You'll uncomment `state_bucket_name` after Part C completes.

    **Apply to create the state bucket** (this is the bucket every other piece of Day 3 will use):

    ```bash
    terraform plan
    terraform apply
    ```
    Review the plan, then type `yes` at the apply prompt. The apply creates an `aws_s3_bucket` named `<student_id>-terraform-state-<random6>` (the random suffix guarantees the name is globally unique — no two students can collide).

    **Capture the bucket name** — you'll paste it into `lab1/networking`'s backend in Step 17, and into your own `terraform.tfvars` in Step 19:

    ```bash
    terraform output state_bucket_name
    ```
    Expected output (yours will have a different random suffix):

    ```
    state_bucket_name = "user07-terraform-state-x8k2m4"
    ```

    **Write this value down.** Every reference to "your state bucket" later in the lab means this exact value.

    **Migrate this state to the new remote backend.** Up to now everything has been on local state (because the backend block in `providers.tf` was commented out — the bucket didn't exist yet). The bucket now exists, so we can flip on the remote backend.

    Open `providers.tf` and **uncomment** the backend block, then paste in your bucket name and your assigned region:

    ```hcl
    terraform {
      required_version = ">= 1.10.0"

      backend "s3" {
        bucket       = "<paste-the-state_bucket_name-output-here>"
        key          = "lab1-app/terraform.tfstate"
        region       = "<your-assigned-region>"   # e.g. us-east-2
        encrypt      = true
        use_lockfile = true
      }

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.0"
        }
      }
    }
    ```

    Now re-init with the migration flag so Terraform copies your existing local state into the bucket:

    ```bash
    terraform init -migrate-state
    ```
    When prompted *"Do you want to copy existing state to the new backend?"*, type `yes`. Terraform pushes your current workspace's state file up to S3 at `env:/<workspace>/lab1-app/terraform.tfstate`. Verify:

    ```bash
    aws s3 ls "s3://$(terraform output -raw state_bucket_name)/" --recursive
    ```
    You should see a key under `env:/<your-current-workspace>/lab1-app/`. Other workspaces (`staging`, `prod`, etc.) will get their own `env:/<workspace>/` prefix the first time you `terraform apply` while sitting in them — workspaces don't get a remote state file until they actually have state to write.

13. **Review the Workspace Safety Guard**

    Open `workspace_guard.tf` and examine the safety mechanism.

    > **What is `null_resource`?** A `null_resource` is a placeholder resource that doesn't create any actual infrastructure. It's useful for running provisioners or, as we use it here, for attaching `lifecycle` blocks with preconditions. The preconditions are evaluated during `terraform plan`, so invalid workspaces are caught before any real resources are touched.

    ```hcl

    # Workspace Safety Guard
    # Prevents accidental operations in wrong workspace

    locals {
      # Define allowed workspaces
      allowed_workspaces = ["dev", "staging", "prod"]

      # Production requires extra confirmation
      is_production = terraform.workspace == "prod"
    }

    # Block operations in default workspace
    resource "null_resource" "workspace_guard" {
      lifecycle {
    precondition {
      condition     = terraform.workspace != "default"
      error_message = <<-EOT
        ERROR: Cannot run Terraform in 'default' workspace.

        Please select an environment workspace:
          terraform workspace select dev
          terraform workspace select staging
          terraform workspace select prod

        Or create a new workspace:
          terraform workspace new dev
      EOT
    }

    precondition {
      condition     = contains(local.allowed_workspaces, terraform.workspace) || startswith(terraform.workspace, "feature-")
      error_message = <<-EOT
        ERROR: Workspace '${terraform.workspace}' is not allowed.

        Allowed workspaces: ${join(", ", local.allowed_workspaces)}
        Or use a feature branch workspace: feature-*
      EOT
    }
      }
    }

    # Production warning output
    output "production_warning" {
      value = local.is_production ? "WARNING: You are operating in PRODUCTION!" : null
    }
    ```
    **How it works:**
    - `precondition` blocks are evaluated during `terraform plan` when Terraform processes this resource
    - If a precondition fails, Terraform stops planning immediately -- no resources are created or modified
    - First precondition blocks the `default` workspace entirely
    - Second precondition allows only `dev`, `staging`, `prod`, or `feature-*` workspaces
    - Production workspace triggers a warning output

14. **Test the Workspace Guard**

    Switch to default and try to plan:

    ```bash
    terraform workspace select default
    terraform plan
    ```
    **Expected error:**
    ```
    Error: Resource precondition failed

      on workspace_guard.tf line X, in resource "null_resource" "workspace_guard":

    ERROR: Workspace 'default' is not allowed.

    Allowed workspaces: dev, staging, prod
    Or use a feature branch workspace: feature-*
    ```
    The guard **prevented** an accidental apply to an unconfigured workspace. (Both preconditions in `workspace_guard.tf` fail for the `default` workspace; Terraform surfaces the "Workspace 'X' is not allowed" message because the second precondition's error_message is the more general one.)

15. **Use a Valid Workspace**

    ```bash
    terraform workspace select dev
    terraform plan
    ```
    Now the plan succeeds. The guard allowed `dev` because it's in the allowed list.

16. **Test Feature Branch Pattern**

    ```bash
    terraform workspace new feature-login-fix
    terraform plan
    ```
    The plan succeeds because `feature-*` workspaces are allowed for ephemeral feature branch environments.

    > **When to use feature workspaces:** In CI/CD pipelines, teams often create temporary workspaces like `feature-login-fix` or `pr-123` to test infrastructure changes in isolation before merging to main. After the PR is merged, the workspace and its resources are destroyed. This keeps dev/staging/prod clean while enabling safe experimentation.

    ```bash

    # Clean up the feature workspace
    terraform workspace select dev
    terraform workspace delete feature-login-fix
    ```
    ---

## Task 3: Cross-State Dependencies with terraform_remote_state (15 min)

The networking team maintains the VPC. Your application team needs the VPC ID and subnet IDs without hardcoding them. You'll use `terraform_remote_state` to create this cross-state dependency.

17. **Deploy the "Networking" State**

    First, deploy infrastructure that simulates the networking team's state:

    ```bash
    cd ~/Advanced_Terraform/lab1/networking
    ```

    Open `providers.tf` and configure your backend. **Paste the bucket name from the `state_bucket_name` output of `lab1/state-infra` (Step 12 of Part A)** — not a Day 1-2 bucket and not a guessed name:

    ```hcl
    terraform {
      required_version = ">= 1.10.0"

      backend "s3" {
        bucket       = "<paste-state_bucket_name-output-here>"   # from `terraform output` in lab1/state-infra
        key          = "networking/terraform.tfstate"             # Note: NO workspace prefix
        region       = "<your-assigned-region>"                   # e.g. us-east-2 — match what your instructor assigned
        encrypt      = true
        use_lockfile = true
      }

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.0"
        }
      }
    }
    ```

    Configure and deploy:

    ```bash
    cp terraform.tfvars.example terraform.tfvars

    # Edit terraform.tfvars with your account
    terraform init
    terraform plan
    terraform apply
    ```
    Review the plan output. When it looks correct, type `yes` at the apply prompt.

    **Expected outputs:**
    ```
    Outputs:

    security_group_id = "sg-xxxxxxxxx"
    subnet_id = "subnet-xxxxxxxxx"
    vpc_id = "vpc-xxxxxxxxx"
    ```

    **Record these values** -- you'll verify the remote_state reads them correctly.

18. **Review the Application Configuration**

    ```bash
    cd ~/Advanced_Terraform/lab1/state-infra
    ```

    Open `main.tf` and find the `terraform_remote_state` data source:

    ```hcl

    # Cross-state dependency: Read VPC info from networking state
    data "terraform_remote_state" "networking" {
      backend = "s3"

      config = {
    bucket = var.state_bucket_name
    key    = "networking/terraform.tfstate"
    region = "<your-assigned-region>"  # e.g. us-east-2
      }
    }

    locals {
      # Values from networking state
      vpc_id            = data.terraform_remote_state.networking.outputs.vpc_id
      subnet_id         = data.terraform_remote_state.networking.outputs.subnet_id
      security_group_id = data.terraform_remote_state.networking.outputs.security_group_id

      # Environment from workspace
      environment = terraform.workspace
    }

    # Application resource that uses networking outputs
    resource "aws_ssm_parameter" "app_config" {
      name  = "/${var.account}/${local.environment}/app-config"
      type  = "String"
      value = jsonencode({
    environment       = local.environment
    vpc_id            = local.vpc_id
    subnet_id         = local.subnet_id
    security_group_id = local.security_group_id
    deployed_at       = timestamp()
      })

      tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Workspace   = terraform.workspace
      }
    }
    ```

    **Key pattern:** The application reads networking values from the shared state file. If networking changes (new VPC, new subnets), the app sees the new values on next apply.

    > **Production considerations:**
    > - **Tight coupling:** `terraform_remote_state` creates a dependency between state files. If the networking state is unavailable, your app plan fails. For looser coupling, production teams often use AWS data sources (e.g., `data "aws_vpc"` with tags) or store values in SSM Parameter Store.
    > - **Security:** Any team with S3 read access to the networking state can see ALL its outputs. Design outputs carefully -- never expose secrets like database passwords.
    > - **Graceful fallbacks:** For optional dependencies, use the `defaults` argument: `defaults = { vpc_id = null }` to handle missing outputs without failing.

19. **Update Variables for Remote State**

    Open `terraform.tfvars` and **uncomment** the `state_bucket_name` line (it was commented out when you copied from the example), pasting in the bucket name you captured in Step 18:

    ```hcl
    student_id        = "userXX"            # already set in Step 12
    account           = "userXX"            # already set in Step 12
    state_bucket_name = "userXX-terraform-state-abc123"  # <- uncomment + paste your actual bucket
    ```

    > **Why this matters:** the `terraform_remote_state.networking` data source in `main.tf` is gated on `state_bucket_name` being set — until you fill this in, Part D is dormant and Part A's plan/apply succeed unchanged. Once you set it, Terraform reads the networking outputs from your lab1/networking state and creates the `app_config` SSM parameter.

20. **Deploy the Application**

    Return to the application directory (state-infra) before deploying — Part D's app config lives there, alongside the bootstrap config from Step 12:

    ```bash
    cd ~/Advanced_Terraform/lab1/state-infra
    terraform plan
    ```
    (If you get a workspace_guard error here, you switched workspaces during Part B's experiments. Recover and continue.)

    **Observe the plan:** Notice that `vpc_id`, `subnet_id`, and `security_group_id` are read from the networking state -- not hardcoded.

    ```bash
    terraform apply
    ```
    Type `yes` when prompted.

21. **Verify Cross-State Dependency**

    ```bash
    terraform output
    ```
    **Expected output:**
    ```
    app_config_ssm_parameter = "/userxx/dev/app-config"
    networking_vpc_id = "vpc-xxxxxxxxx"
    ```

    Verify the VPC ID matches what you recorded from the networking deployment.

22. **Understand State Boundaries**

    Why did we separate networking from application state?

    | Factor | Networking | Application |
    |--------|------------|-------------|
    | **Change frequency** | Rarely (VPC is stable) | Often (new features, deployments) |
    | **Team ownership** | Networking team | Application team |
    | **Blast radius** | High (affects all apps) | Low (only this app) |
    | **Access required** | Read-only for app teams | Full access for app team |

    **Design principle:** Resources that change together and are owned by the same team belong in the same state. Resources with different lifecycles or owners should be in separate states.

---

## Task 4: State Inspection and Troubleshooting (10 min)

When something breaks in production, you'll need to read the state file directly. This task practices the operational skills you'll use in real outages — most of which you'll only need once or twice in your career, but having seen the commands once makes the difference between a 10-minute fix and an hour of stress.

23. **Pull the raw state file with `terraform state pull`**

    > Before you run anything in this task: **confirm you're still in `lab1/state-infra/` and on the `dev` workspace.** If you're not sure, check (you've done this several times already). If you're not, fix it before continuing.

    Dump the current workspace's state to a local file so you can inspect it without affecting the live state:

    ```bash
    terraform state pull > /tmp/lab1-state.json
    wc -l /tmp/lab1-state.json
    ```
    The state is a JSON document. The `lineage` and `serial` keys at the top identify this state file's identity and version; the `resources` array is the interesting part.

24. **Inspect with `jq`**

    Use `jq` to navigate the state. The first command — count of resource types — is a good "what's actually in this state?" sanity check:

    ```bash
    jq '.resources[].type' /tmp/lab1-state.json | sort | uniq -c
    ```
    Find a specific resource by type:

    ```bash
    jq '.resources[] | select(.type == "aws_ssm_parameter")' /tmp/lab1-state.json
    ```
    Extract just the AWS-side IDs (useful when you need them for a CLI command and don't have them stored elsewhere):

    ```bash
    jq -r '.resources[].instances[].attributes.id // empty' /tmp/lab1-state.json
    ```
    > **Why this matters in real outages.** When a `terraform apply` half-finishes (network drop, interrupted process), the state on disk and the state in S3 can diverge. `state pull` shows you what S3 thinks; `aws ec2 describe-vpcs --vpc-ids ...` shows you what AWS thinks. Reconciling those two views is the first 10 minutes of any "Terraform is broken" investigation.

25. **Conceptual: stuck locks and `terraform force-unlock`**

    With S3 native locking, a stale lock can occur if `terraform apply` is interrupted mid-flight (Ctrl-C, SSH timeout, CodeBuild stop). The cleanup command:

    ```bash
    # Don't run this for practice — read about it.
    terraform force-unlock <LOCK_ID>
    ```
    The `<LOCK_ID>` appears in the lock-conflict error message that the next caller sees. You can also see the lock object in S3:

    ```bash
    aws s3 ls "s3://<your-state-bucket-name>/env:/dev/lab1-app/"   # use the bucket from terraform output
    # Look for the .tflock file
    ```
    If you don't see the `env:/` prefix in your bucket, go back to Step 12 and run the migration block at the end.

    Force-unlock should be a "you'll need it once" tool, not a regular operation. If you find yourself running it often, something else is wrong (concurrent CI runs, runaway processes, broken cleanup). Knowing the command exists is the goal of this step.

---

## Task 5: Workspaces vs. Directory Structure Decision (10 min)

Now you'll implement the same deployment using a directory structure to compare with workspaces.

26. **Review the Directory Structure Pattern**

    ```bash
    cd ~/Advanced_Terraform/lab1/directories
    ls -la
    ```

    **Structure:**
    ```
    lab1/directories/
    ├── modules/
    │   └── app/
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
    ├── dev/
    │   ├── main.tf
    │   ├── providers.tf
    │   └── terraform.tfvars
    └── staging/
        ├── main.tf
        ├── providers.tf
        └── terraform.tfvars
    ```

27. **Review the Module**

    ```bash
    cat modules/app/main.tf
    ```

    **The shared module:**
    ```hcl

    # modules/app/main.tf - Shared application logic
    variable "account" {}
    variable "environment" {}
    variable "state_bucket_name" {}

    data "terraform_remote_state" "networking" {
      backend = "s3"
      config = {
    bucket = var.state_bucket_name
    key    = "networking/terraform.tfstate"
    region = "<your-assigned-region>"  # e.g. us-east-2
      }
    }

    resource "aws_ssm_parameter" "app_config" {
      name  = "/${var.account}/${var.environment}/app-config-dir"
      type  = "String"
      value = jsonencode({
    environment = var.environment
    vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id
    pattern     = "directory-structure"
      })
    }
    ```
    28. **Review an Environment Directory**

    ```bash
    cat dev/main.tf
    ```

    **The dev environment:**
    ```hcl

    # dev/main.tf - Dev environment configuration
    module "app" {
      source = "../modules/app"

      account        = var.account
      environment       = "dev"  # Explicit, not from workspace
      state_bucket_name = var.state_bucket_name
    }
    ```
    **Key difference:** The environment is EXPLICIT (`environment = "dev"`) rather than derived from `terraform.workspace`.

29. **Pick your pattern**

    You've now seen both approaches end-to-end. The slide deck covers the trade-offs in detail; see **Appendix A** at the end of this lab for the comparison table and the hybrid recommendation if you want a quick reference while making the call on a real project.

---

## Bonus Task: Prove Workspace State Isolation (optional, ~3 min)

Optional — skip if you're short on time. This task gives you a concrete look at how workspaces keep state files separated in S3. No new infrastructure is created.

30. **Materialize the prod workspace's state file**

    > Confirm you're in `lab1/state-infra/` on the `dev` workspace.

    ```bash
    cd ~/Advanced_Terraform/lab1/state-infra
    # 1. Capture the bucket name from dev's state (after we switch workspaces,
    #    `terraform output` won't see it).
    BUCKET=$(terraform output -raw state_bucket_name)
    echo "$BUCKET"

    # 2. Switch to prod and force terraform to write the workspace's state
    #    file out to S3. -refresh-only doesn't create or change any resources;
    #    it just rewrites state, which materializes the prod state object.
    terraform workspace select prod
    terraform apply -refresh-only -auto-approve
    ```
    ```bash
    # 3. List every state file in your bucket
    aws s3 ls "s3://$BUCKET/env:/" --recursive
    ```
    Expected output (one key per workspace that's been applied):

    ```
    env:/dev/lab1-app/terraform.tfstate
    env:/prod/lab1-app/terraform.tfstate
    ```

    Same config, different workspaces, completely separated state files sitting side-by-side in the same bucket. That's the isolation guarantee.

    ```bash
    # 4. Switch back to dev for the cleanup task.
    terraform workspace select dev
    ```
    > **Why we didn't run a real `terraform apply` in prod:** this lab's `main.tf` is the bootstrap config — it tries to create a single S3 bucket whose name doesn't include the workspace. A real `apply` in prod would try to create a *second* bucket with the same name and fail. In production code, resource names are workspace-aware (e.g., `"${terraform.workspace}-app-config"`) so the same config can be deployed independently in each workspace. We use `-refresh-only` here to demonstrate state isolation without that refactor.

---

## Task 6: Cleanup (5 min)

The state bucket you created in Step 12 is a **bootstrap resource** — it holds the state file for this very configuration. Terraform can't destroy a bucket that's actively storing its own state (the state file would vanish mid-operation). The standard pattern in real orgs: treat the bootstrap state bucket as **manually managed and never deleted** — it's the durable record of every environment's history, and once a team adopts it, removing it would orphan every state file pointing at it. The steps below follow that pattern: drop the bucket from terraform's view, destroy everything else, and **leave the bucket in place**.

31. **Capture the bucket name and remove bootstrap resources from state**

    > Confirm you're in `lab1/state-infra/` on the `dev` workspace.

    ```bash
    # Capture the bucket name BEFORE state rm — afterwards terraform won't know it.
    BUCKET=$(terraform output -raw state_bucket_name)
    echo "$BUCKET"
    ```
    Drop the bucket and its supporting resources from terraform's tracking. The actual AWS resources stay — terraform just stops managing them:

    ```bash
    terraform state rm aws_s3_bucket.terraform_state
    terraform state rm aws_s3_bucket_versioning.terraform_state
    terraform state rm aws_s3_bucket_server_side_encryption_configuration.terraform_state
    terraform state rm aws_s3_bucket_public_access_block.terraform_state
    terraform state rm random_string.suffix
    ```
    32. **Destroy the rest**

    ```bash
    terraform destroy -auto-approve
    ```
    This destroys what's left in state: `null_resource.workspace_guard`, `time_sleep.locking_demo`, `aws_ssm_parameter.lock_demo`, and `aws_ssm_parameter.app_config` (if Part D was active). The bucket is untouched.

33. **Destroy networking (optional)**

    If you're not continuing to Lab 2 today:

    ```bash
    cd ~/Advanced_Terraform/lab1/networking
    terraform destroy -auto-approve
    ```
    **Keep the networking state if continuing to Lab 2** — Lab 2's import flow expects this VPC and SG to exist.

34. **Clean up workspaces**

    ```bash
    cd ~/Advanced_Terraform/lab1/state-infra
    terraform workspace select default
    # Some workspaces may already be gone after destroy if their state file
    # was the only env:/<ws>/ object — that's fine.
    terraform workspace delete dev     2>/dev/null || echo "(dev not present)"
    terraform workspace delete staging 2>/dev/null || echo "(staging not present)"
    terraform workspace delete prod    2>/dev/null || echo "(prod not present)"

    ```
    35. **Leave the bootstrap bucket in place**

    The bucket and its versioned state files still exist in S3 from Step 31's `state rm` — and that's intentional. **Do not delete it.** Labs 2-4 reference this same bucket, and in any real environment a state bucket is treated as durable, versioned, audit-grade storage that you never tear down as part of routine teardown.

    > **Why the lab doesn't ship a delete command:** the bucket has versioning enabled, so `aws s3 rb --force` would leave old object versions and delete markers behind and the bucket-delete itself would fail with `BucketNotEmpty`. Even with the correct version-aware empty sequence (`aws s3api list-object-versions` + `delete-objects`), the right answer in production is still "don't delete the state bucket." Sandbox lab accounts are wiped between cohorts, so the bucket goes with the account — no manual cleanup needed here.

    Confirm the bucket is no longer in terraform's state but still exists in S3:

    ```bash
    terraform state list | grep terraform_state || echo "bucket not in state (correct)"
    aws s3 ls "s3://$BUCKET/" | head
    ```
    ---

## Troubleshooting

### Remote State Access Denied

```
Error: error configuring S3 Backend: AccessDenied
```

Verify your bucket name is correct and you have permissions:
```bash
aws s3 ls s3://your-bucket-name/
```
### State File Not Found (terraform_remote_state)

```
Error: Unable to find remote state
```

Ensure the networking state was deployed first:
```bash
aws s3 ls s3://your-bucket-name/networking/
```
### Workspace Guard Blocking Apply

This is intentional! The guard is working. Select a valid workspace:
```bash
terraform workspace select dev
```
### Lock Error

If lock persists after operation completed:
```bash
terraform force-unlock <LOCK_ID>
```
Use with caution -- only when certain no operation is running.

---

## Knowledge Check

**Q1: What command shows which workspace you're currently in?**

*A: `terraform workspace show` or `terraform workspace list` (asterisk marks current)*

**Q2: How does S3 backend organize state files for workspaces?**

*A: Non-default workspaces get an `env:/<workspace>/` prefix. So `dev` workspace with key `app/terraform.tfstate` becomes `env:/dev/app/terraform.tfstate`.*

**Q3: Why use a precondition in null_resource instead of checking workspace in each resource?**

*A: The precondition runs BEFORE any resource operations and fails fast. Checking in each resource would allow partial applies before failure.*

**Q4: What's the security implication of terraform_remote_state?**

*A: Any team that can read the networking state file can see all its outputs. Design outputs carefully -- don't expose secrets. Consider using data sources for sensitive values.*

**Q5: When would you choose workspaces over directory structure?**

*A: When environments are structurally identical (same resources, different values), when you need rapid iteration, or for ephemeral feature branch environments.*

---

## Lab Completion Checklist

- [ ] Cloned lab repository and configured S3 backend
- [ ] Created dev, staging, and prod workspaces
- [ ] Understood how workspaces affect state paths (`env:/`)
- [ ] Used `terraform.workspace` in configuration
- [ ] Implemented workspace safety guard that blocks `default` workspace
- [ ] Tested `feature-*` workspace pattern
- [ ] Deployed networking infrastructure with outputs
- [ ] Configured `terraform_remote_state` to read networking outputs
- [ ] Deployed application that consumes networking state
- [ ] Verified cross-state dependency with matching VPC IDs
- [ ] Compared workspaces vs. directory structure patterns
- [ ] Cleaned up resources

---

## Cost Considerations

| Resource | Cost |
|---|---|
| VPC (networking state) | Free (no NAT Gateway) |
| SSM Parameters | Free (standard tier) |
| S3 State Storage | ~$0.00 (state files < 50 KB) |

**Keep** the S3 bucket for Labs 2, 3, and 4.

---

## Next Steps

In **Lab 2: Import Legacy Application**, you will:
- Deploy a "legacy" application simulating console-created infrastructure
- Use `import` blocks to bring resources under Terraform management
- Practice state operations to resolve import conflicts
- Store imported state using the patterns learned today

---

## Additional Resources

| Resource | URL |
|---|---|
| Terraform Workspaces | https://developer.hashicorp.com/terraform/cli/workspaces |
| When to Use Workspaces | https://developer.hashicorp.com/terraform/cli/workspaces#when-to-use-workspaces |
| terraform_remote_state | https://developer.hashicorp.com/terraform/language/state/remote-state-data |
| Preconditions and Postconditions | https://developer.hashicorp.com/terraform/language/expressions/custom-conditions |
| S3 Backend Configuration | https://developer.hashicorp.com/terraform/language/settings/backends/s3 |

---

## Appendix A: Workspaces vs. Directory Structure — Reference

This material is covered in the lecture/slide deck; it lives here as a quick reference you can come back to when you're picking a pattern on a real project.

### Comparison

| Aspect | Workspaces | Directory Structure |
|--------|------------|---------------------|
| **Switching environments** | `terraform workspace select staging` | `cd ../staging` |
| **Accidental wrong env** | Easy — just a command | Harder — must cd to wrong directory |
| **Code duplication** | None | Some (providers.tf, main.tf) |
| **Environment differences** | Requires conditionals | Clean separation |
| **Module versioning** | All envs use same version | Each can pin different version |
| **CI/CD pipelines** | Pass workspace as variable | Change directory |

### Recommended pattern: hybrid

| Use **workspaces** for | Use **directory structure** for |
|------------------------|----------------------------------|
| Feature-branch ephemeral environments | Production environments (explicit separation) |
| Environments that are structurally identical | Environments that need different resources |
| Rapid iteration during development | When teams want to pin different module versions |

### Layout you'd see in a real org

```
infrastructure/
├── networking/                    # No workspaces — one state
│   └── terraform.tfstate
├── applications/
│   ├── payments/                  # Uses workspaces for dev/staging
│   │   ├── main.tf
│   │   └── (dev, staging workspaces)
│   └── checkout/
│       └── ...
└── production/                    # Separate directory for prod
    ├── payments/
    │   ├── main.tf               # Can have prod-only resources
    │   └── backend.tf            # Separate state path
    └── checkout/
```

Networking is a single state (rarely changes, shared). Non-prod environments use workspaces for speed. Prod gets a separate directory so you can pin different module versions and accept different resources without conditionals.
