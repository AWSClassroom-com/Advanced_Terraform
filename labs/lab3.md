# Lab 3: Pipeline Operations

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Chapter** | CI/CD Pipelines for Multi-Region Deployment |
| **Duration** | 80 minutes |
| **Difficulty** | Advanced |
| **Version** | 4.0 |
| **Prerequisites** | Lab 1 completed (state bucket created and captured) |
| **Terraform** | >= 1.10.0 |
| **Lab Files** | [github.com/AWSClassroom-com/Advanced_Terraform](https://github.com/AWSClassroom-com/Advanced_Terraform) → `lab3/pipeline/`, `lab3/app-repo/` |
| **Answers** | [`answers/lab3/`](../answers/lab3/) — complete code, including the Step 20-24 buildspec. Try the lab first. |
---

## Lab Overview

### Narrative

After a production incident in Days 1-2, your CTO mandated: *"No human runs terraform apply against production from their laptop."* The platform team built a CI/CD pipeline, but it has only been tested with simple SSM parameters.

Today, you'll push **real infrastructure** through the pipeline: a complete web application stack with VPC, networking, and EC2 instances. You'll deploy to staging (us-east-1), verify it works, approve, then promote to production (us-west-2). At the end, you'll tear both environments down and see why the teardown does not go through the pipeline.

### What You'll Deploy

Each student deploys their own isolated infrastructure, tagged with their IAM username:

| Resource | Purpose |
|----------|---------|
| VPC | `10.10.0.0/16` in staging, `10.20.0.0/16` in prod — one /16 per environment |
| Public Subnet | Hosts the web server |
| Internet Gateway | Enables internet access |
| Route Table | Routes traffic to IGW |
| Security Group | Allows HTTP (80) inbound only |
| EC2 Instance | Apache web server |

### Learning Objectives

By the end of this lab, you will:

- **Deploy real infrastructure through a pipeline** (not just SSM parameters)
- **Experience multi-region promotion** (staging in us-east-1 → prod in us-west-2)
- **Verify deployments** by curling the web servers
- **Practice the approval workflow** with actual infrastructure at stake
- **Tear down through the pipeline** demonstrating full lifecycle management

---

## Architecture Overview

![CI/CD Pipeline Architecture](../assets/images/lab3_pipeline_architecture.png)

*Figure: The 8-stage CodePipeline runs in us-east-2 and deploys to staging (us-east-1) first, then promotes to production (us-west-2) after manual approval. Each environment gets its own isolated VPC with EC2 running Apache.*

---

## Task 1: Review Pipeline Infrastructure (10 min)

1. **Review the pipeline and its eight stages**

    ```bash
    cd ~/Advanced_Terraform/lab3/pipeline
    ls -la
    cat codepipeline.tf
    ```

    | File | Purpose |
    |------|---------|
    | `providers.tf` | Backend and AWS provider |
    | `variables.tf` | Your user ID and state bucket name |
    | `iam.tf` | IAM roles for CodeBuild and CodePipeline |
    | `codebuild.tf` | Build projects for validate, plan, apply |
    | `codepipeline.tf` | Pipeline stages with approval gates |
    | `outputs.tf` | Repository URL, pipeline name |

    **The 8-stage flow:**

    1. **Source** - Polls CodeCommit for pushes to `main` (`PollForSourceChanges = "true"`)
    2. **Validate** - `terraform fmt -check` + `terraform validate`
    3. **Plan-Staging** - Plans for us-east-1, saves artifact
    4. **Approve-Staging** - Manual approval gate
    5. **Apply-Staging** - Applies saved plan to us-east-1
    6. **Plan-Production** - Plans for us-west-2, saves artifact
    7. **Approve-Production** - Manual approval gate
    8. **Apply-Production** - Applies saved plan to us-west-2

    Notice `pipeline_type = "V2"` near the top of the resource. Left unset, the type follows
    whichever provider version your `init` resolved — two students running identical code can end
    up on different types, with different execution modes, different billing, and different
    CloudWatch metrics. Lab 4's dashboard depends on knowing which you have.

2. **Read the buildspec pattern and the two IAM roles**

    Each stage runs in a CodeBuild project, and `codebuild.tf` embeds the **buildspec** — the shell
    script CodeBuild runs — inline in each project. Look at the plan and apply projects:

    ```bash
    grep -A2 'terraform plan -out' codebuild.tf
    grep -A2 'terraform apply' codebuild.tf
    ```

    ```bash
    # plan-stage buildspec
    terraform plan -out=tfplan

    # apply-stage buildspec, after the manual approval
    terraform apply -auto-approve tfplan
    ```

    This is the **Golden Rule of Terraform automation**: the plan stage produces a binary plan
    artifact, and the apply stage executes **that exact artifact** instead of re-planning. The
    approver reviews what `plan` produced, and `apply` does that and nothing else. If apply
    re-planned, state or AWS could have drifted between approval and execution, and the apply would
    silently run a different change than the one that was reviewed.

    Two IAM roles in `iam.tf` split the work:

    | Role | Purpose |
    |------|---------|
    | CodePipeline Role | Orchestrates the pipeline, triggers builds |
    | CodeBuild Role | Executes Terraform, creates AWS resources |

---

## Task 2: Deploy Pipeline Infrastructure (10 min)

> **Use the same `user_id` you set in Lab 1.** It is validated against `^user[0-9]{2}$`, and every resource here is prefixed with it — `user07-terraform-repo`, `user07-terraform-pipeline`, and so on. Lab 4's dashboard looks those names up, so a different value breaks it.

3. **Configure Variables**

    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

    Edit `terraform.tfvars`. Use the **same concrete ID you used in Lab 1**. The validator accepts `userNN` only, so `userXX` is rejected and `user07` is the shape it wants. Using a different ID than Lab 1 breaks the shared naming Lab 4's dashboard depends on:

    ```hcl
    user_id        = "user07"                         # ← REPLACE 07 with YOUR assigned student number (same value you used in Lab 1)
    state_bucket_name = "user07-terraform-state-ab12cd"  # ← REPLACE with YOUR actual bucket name from Lab 1 `terraform output state_bucket_name`
    ```

4. **Deploy Pipeline**

    ```bash
    terraform init \
        -backend-config="bucket=<your Lab 1 state bucket>" \
        -backend-config="region=<your bucket region>"
    terraform plan
    terraform apply
    ```
    Review the plan, then type `yes` at the apply prompt. Expected: ~15 resources (CodeCommit, CodeBuild projects, CodePipeline, IAM roles, S3 artifacts bucket).

    **Note the outputs.** You'll use the CodeCommit clone URL in Task 3, and the pipeline name to find your pipeline in the AWS Console at the next step:

    ```
    repository_clone_url_http = "https://git-codecommit.us-east-2.amazonaws.com/v1/repos/userXX-terraform-repo"
    pipeline_name            = "userXX-terraform-pipeline"
    ```

    > **Don't click the `repository_clone_url_http` in a browser** — that's the CodeCommit HTTPS endpoint; it's reachable from `git clone` but a browser hit will prompt for a login. We'll use it via git in Task 3.

5. **Open the Pipeline in the AWS Console**

    Navigate manually (Terraform doesn't emit a console URL):

    1. AWS Console → **CodePipeline** → **Pipelines**
    2. Confirm you're in **us-east-2**, your primary region (top-right region picker) — that is where the pipeline itself runs. The Apply-Staging and Apply-Production stages deploy *to* us-east-1 and us-west-2, but the pipeline, the repo and the build projects all live in the primary region.
    3. Click your pipeline (`userXX-terraform-pipeline`, the `pipeline_name` from the output above)
    4. You'll see the 8 stages laid out. They'll currently be in a failed/idle state — the CodeCommit repo is empty, so the source stage has nothing to flow through. Task 3 fixes that.

---

## Task 3: Push Web Application Code (10 min)

> **Three similar names — read this before you start.** Task 3 touches three things that all sound like "the app repo." Knowing which is which will save you 15 minutes of confusion.
>
> | Name | What it is | Where it lives |
> |---|---|---|
> | **`lab3/app-repo/`** | **Source** Terraform code (modules + per-environment wrappers) that ships with the course. You'll copy *from* here. | Subdirectory of the `Advanced_Terraform` GitHub repo you cloned at the start of the course (`~/Advanced_Terraform/lab3/app-repo/`). |
> | **`userXX-terraform-repo`** | The empty **CodeCommit repository** that Task 2 created. The CodePipeline is wired to watch this repo for pushes. You'll push *to* here. | AWS-side, in your primary region (us-east-2). Listed in the Step 4 output as `repository_clone_url_http = .../repos/userXX-terraform-repo`. |
> | **`webapp-repo`** | The **local working directory name** you'll give to the `git clone` of `userXX-terraform-repo` in Step 7. Just a folder on your lab EC2 instance — the name doesn't have to match the CodeCommit repo. We put it alongside `lab3/pipeline/` and `lab3/app-repo/` so everything for this lab lives in `~/Advanced_Terraform/lab3/`. | `~/Advanced_Terraform/lab3/webapp-repo/` after Step 7 runs. |
>
> **The flow:** clone `userXX-terraform-repo` to local `webapp-repo/` (Step 7) → copy contents of `lab3/app-repo/` into `webapp-repo/` (Step 8) → commit & push from `webapp-repo/` back up to `userXX-terraform-repo` on CodeCommit, which triggers the pipeline.

6. **Configure Git for CodeCommit**

    ```bash
    git config --global credential.helper '!aws codecommit credential-helper $@'
    git config --global credential.UseHttpPath true
    ```
    > **Note on `--global`:** AWS documents the credential helper as a global git config because the helper must be available before any clone. This is appropriate in a dedicated lab environment. In a shared workstation where you have multiple git providers, scope this to a `[includeIf "gitdir:~/work/codecommit/"]` block in `~/.gitconfig` instead, or unset both keys at end-of-session: `git config --global --unset credential.helper && git config --global --unset credential.UseHttpPath`.

7. **Clone the empty CodeCommit repository into a local working directory**

    This clones `userXX-terraform-repo` (the CodeCommit repo) into a new local folder called `webapp-repo/` *inside* the `lab3/` directory — keeping it next to `lab3/pipeline/` and `lab3/app-repo/` so everything related to this lab lives under one roof. The trailing `webapp-repo` argument is just the local folder name — it doesn't change the CodeCommit repo's name on AWS.

    ```bash
    cd ~/Advanced_Terraform/lab3

    # Clone the empty CodeCommit repo (userXX-terraform-repo) into a local dir named webapp-repo/
    git clone $(terraform -chdir=pipeline output -raw repository_clone_url_http) webapp-repo
    cd webapp-repo
    ```
    You should now be in `~/Advanced_Terraform/lab3/webapp-repo/` — an empty git working tree pointing at the CodeCommit repo.

8. **Copy the source Terraform from `lab3/app-repo/` into your clone**

    `lab3/app-repo/` (the course-supplied source) gets copied into `webapp-repo/` (your local clone of the CodeCommit repo). After this step, your CodeCommit clone has real content ready to commit and push.

    ```bash
    # You're in ~/Advanced_Terraform/lab3/webapp-repo/ from Step 7.
    cp -r ../app-repo/* .
    ls -la
    ```

    **Files copied** (modular layout — per-environment wrappers calling a shared module):

    | File | Purpose |
    |------|---------|
    | `environments/staging/main.tf` | Staging wrapper — partial `backend "s3"` block + AWS provider (`var.staging_region`, default us-east-1) + `module "app"` call with `environment = "staging"`. Exposes `public_ip`, `instance_id`, `vpc_id` outputs. |
    | `environments/prod/main.tf` | Prod wrapper — same shape, different region (`var.prod_region`, default us-west-2), different state key. Same outputs. |
    | `modules/app/main.tf` | Shared application module — VPC, public subnet, IGW, route table, route table association, security group, and EC2 instance running Apache. Mirrors the Day 1-2 pattern so the skills carry over directly. |
    | `modules/app/variables.tf` | Module inputs: `user_id`, `environment`, `instance_count` |
    | `modules/app/outputs.tf` | Module outputs: `public_ip`, `instance_id`, `vpc_id`, `api_url` (null for this module — populated by the bonus serverless module instead). |
    | `modules/app-serverless/` | **Bonus** — Lambda + API Gateway HTTP API. Drop-in replacement for `modules/app/` with the same interface. Used only in the optional Challenge at the end of this lab. |

    > **Why VPC + EC2 (and not just SSM parameters)?** A pipeline lab is most convincing when students can see real infrastructure come up. The deployed stack mirrors what Days 1-2 built — same `aws_vpc` / `aws_subnet` / `aws_security_group` / `aws_instance` shape — so the skills carry over directly. Apache writes a tiny `index.html` tagged with the environment and user ID, and the verification step is a `curl` against the public IP.

9. **Review the directory layout you just copied in**

    ```bash
    # You're in ~/Advanced_Terraform/lab3/webapp-repo/ from Step 8.
    pwd
    find environments modules -type f
    ```

    Expected layout:

    ```
    environments/
      staging/main.tf              # staging wrapper — backend + provider + module "app" call + outputs
      prod/main.tf                 # prod wrapper — same shape, different region/keys
    modules/
      app/main.tf                  # shared module — VPC + subnet + IGW + RT + RTA + SG + EC2 (httpd)
      app/variables.tf             # module inputs: user_id, environment, instance_count
      app/outputs.tf               # public_ip, instance_id, vpc_id, api_url (null for EC2 module)
      app-serverless/main.tf       # BONUS: Lambda + API Gateway alternative
      app-serverless/variables.tf  # same interface as modules/app
      app-serverless/outputs.tf
      app-serverless/lambda/index.js
    ```

    > **Two modules, one interface.** Both `modules/app/` (EC2 main path) and `modules/app-serverless/` (bonus) accept the same inputs and expose the same outputs (`public_ip`, `api_url`, `instance_id`, `vpc_id`). For EC2: `public_ip` is set, `api_url` is null. For serverless: it flips. The wrapper outputs surface all four either way, so verification commands don't need to know which module is in use. You'll only touch `app-serverless/` if you do the Challenge.

10. **Read the staging wrapper and the shared module**

    ```bash
    # Still in ~/Advanced_Terraform/lab3/webapp-repo/
    cat environments/staging/main.tf
    cat modules/app/main.tf
    cat modules/app/variables.tf
    ```

    Things to notice:

    - **`environments/staging/main.tf`** declares the `backend "s3"` block (state lands in your Lab 1 bucket at key `pipeline/staging/terraform.tfstate`), pins the AWS provider region to **`var.staging_region`** (default us-east-1), attaches `default_tags` including `User = "userXX"`, calls `module "app"` with `environment = "staging"`, and re-exposes the module outputs (`public_ip`, `instance_id`, `vpc_id`, `api_url`) so `terraform output public_ip` works from the wrapper.
    - **`environments/prod/main.tf`** is the same shape — different state key (`pipeline/prod/terraform.tfstate`), different provider region (**`var.prod_region`**, default us-west-2), `environment = "prod"`.
    - **`modules/app/main.tf`** deploys 7 resources per environment: `aws_vpc` (10.10.0.0/16 for staging, 10.20.0.0/16 for prod — avoids Day 1-2's 192.168.0.0/20), `aws_subnet`, `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`, `aws_security_group` (HTTP-only), and `aws_instance` (t3.micro running Apache). The `user_data` writes a tiny env-tagged `index.html` so `curl http://<public_ip>` returns proof the right environment deployed.

11. **Check the wrappers — there is nothing to edit**

    Open `environments/staging/main.tf` and read the top of the file:

    ```bash
    # Still in ~/Advanced_Terraform/lab3/webapp-repo/
    sed -n '1,50p' environments/staging/main.tf
    ```

    Notice what is **not** there. No bucket name, no region literal, no user ID:

    - The `backend "s3"` block declares only `key`, `encrypt`, and `use_lockfile`. The bucket and its region arrive at `terraform init` time, injected by the pipeline.
    - `provider "aws"` reads `var.staging_region`, which defaults to `us-east-1`.
    - `module "app"` and the `User` tag both read `var.user_id`, which the pipeline supplies as `TF_VAR_user_id` from the `user_id` you set in Step 3.

    > **Why this matters.** A value that has to be pasted into several files is a value that gets pasted wrong in one of them. The pipeline already knows your ID, your bucket, and its region — so it passes them in, and these files stay identical for every student in the room.

    `environments/prod/main.tf` is the same shape, reading `var.prod_region` (default `us-west-2`) instead. **Three regions are now in play:** you work in `us-east-2`, staging deploys to `us-east-1`, production to `us-west-2`. To move an environment somewhere else, change the default on that one variable — nothing else in the repo hardcodes a region.

12. **Push to CodeCommit**

    ```bash
    git checkout -b main
    git add .
    git commit -m "Initial web application - VPC + EC2 for staging and prod"
    git push -u origin main
    ```
    ---

## Task 4: Deploy to Staging (15 min)

13. **Watch Pipeline Execute**

    1. Return to the CodePipeline console
    2. Pipeline triggers automatically within 1-2 minutes
    3. Watch it progress through Source → Validate → Plan-Staging

14. **Handle Validate Failure (If Needed)**

    If Validate fails due to formatting:

    ```bash
    cd ~/Advanced_Terraform/lab3/webapp-repo
    terraform fmt -recursive
    git add .
    git commit -m "Fix terraform formatting"
    git push origin main
    ```
15. **Review Staging Plan**

    When pipeline reaches **Plan-Staging**:

    1. In the **Plan-Staging** box, click the action name **Terraform-Plan-Staging**
    2. That opens the execution's **Logs** tab with the CodeBuild output already showing
    3. Scroll to find the plan output:

    ```
    Plan: 7 to add, 0 to change, 0 to destroy.
    ```

    **Resources being created:**
    - 1 VPC
    - 1 Subnet
    - 1 Internet Gateway
    - 1 Route Table
    - 1 Route Table Association
    - 1 Security Group
    - 1 EC2 Instance

16. **Approve Staging Deployment**

    When pipeline reaches **Approve-Staging**:

    1. In the **Approve-Staging** box, click the action name **Approve-Staging-Deploy**
    2. In the **Review** dialog, select **Approve** under **Decision**
    3. Comment: "Reviewed staging plan - creating VPC and EC2 in us-east-1"
    4. Click **Submit**

    > **Why the comment matters.** CodePipeline stores it on the approval and CloudTrail records it. It is the only place the *reason* for a change is recorded, which is exactly what Lab 4's audit queries look for. Don't skip it.

    Watch **Apply-Staging** execute. This takes ~2-3 minutes as the VPC and EC2 are created.

17. **Verify Staging Deployment**

    After Apply-Staging completes, get the staging public IP from the staging state. The state lives at key `pipeline/staging/terraform.tfstate` in your Lab 1 bucket — same bucket as Lab 1, separate key.

    ```bash
    # Get the staging public IP from the staging state file.
    aws s3 cp s3://userXX-terraform-state-SUFFIX/pipeline/staging/terraform.tfstate - --region <bucket-region> | \
        jq -r '.outputs.public_ip.value'
    ```
    Replace `userXX-terraform-state-SUFFIX` with your bucket name and `<bucket-region>` with the region your Lab 1 bucket lives in. (Alternatively, find the IP in the CodeBuild logs: click **Terraform-Apply-Staging** in the Apply-Staging box, then scroll to the `terraform apply` outputs at the end.)

    **Verify the web server is up:**

    ```bash
    curl http://<STAGING_PUBLIC_IP>
    ```
    **Expected output:**

    ```html
    <h1>Sample Web App</h1>
    <p>Environment: staging</p>
    <p>User: userXX</p>
    <p>Deployed via CI/CD Pipeline</p>
    ```

    The HTML comes from the `user_data` script in `modules/app/main.tf` — Apache renders it at `/var/www/html/index.html` on first boot.

---

---

## Task 5: Inject Secrets via Parameter Store and Secrets Manager (15 min)

The pipeline you just deployed hardcodes everything — fine for a lab, dangerous in production. CodeBuild has first-class integration with both AWS Systems Manager Parameter Store and AWS Secrets Manager. Values are pulled at build start and exposed as environment variables; Secrets Manager values never appear in build logs.

This task wires both into the existing buildspec so the pipeline can deploy environment-specific config and credentials without anything sensitive landing in source control.

18. **Store a non-sensitive value in Parameter Store**

    Parameter Store is good for environment-specific config — region, account number, feature-flag toggles, hostnames. Values are visible to anyone with `ssm:GetParameter` and appear in CloudTrail.

    > **Set `$STUDENT` first — do not use `$USER`.** On the lab EC2 box `$USER` is `ec2-user`, not your assigned ID. Step 20 wires the buildspec to `/userXX/lab3/...`, so these paths must match exactly or CodeBuild cannot resolve the value at build start:
    >
    > ```bash
    > export STUDENT="userXX"   # your assigned ID — same value as user_id in Step 3
    > ```

    ```bash
    aws ssm put-parameter \
        --name "/${STUDENT}/lab3/db_host" \
        --type "String" \
        --value "rds.${STUDENT}.example.com" \
        --overwrite
    ```
    Verify:

    ```bash
    aws ssm get-parameter --name "/${STUDENT}/lab3/db_host" --query 'Parameter.Value' --output text
    ```
19. **Store a credential in Secrets Manager**

    Secrets Manager is for values that must NEVER appear in plaintext logs. It encrypts at rest with KMS, supports automatic rotation, and CodeBuild masks the value in build output.

    ```bash
    aws secretsmanager create-secret \
        --name "${STUDENT}/lab3/db_password" \
        --description "Lab 3 demo credential — delete at end of lab" \
        --secret-string "demo-password-do-not-reuse"
    ```
20. **Update the plan-staging buildspec to pull both values**

    > **Why the *plan* stage, not the apply stage?** The apply stage runs `terraform apply tfplan` against a **saved plan file**, and Terraform refuses to accept variables alongside a saved plan (`Error: Can't set variables when applying a saved plan file`) — a saved plan already contains the variable values that were set when it was created. So the secrets have to be resolved at **plan** time and baked into `tfplan`. This also means the values the approver reviews are the values that get applied.

    The buildspecs live inline in `lab3/pipeline/codebuild.tf`. Find the `plan_staging` project and add an `env:` block directly under `version: 0.2`, above `phases:`:

    ```yaml
    version: 0.2
    env:
      parameter-store:
        DB_HOST: /${var.user_id}/lab3/db_host
      secrets-manager:
        DB_PASSWORD: ${var.user_id}/lab3/db_password
    phases:
      ...
    ```
    CodeBuild fetches both values at build start, before any command runs; `$DB_HOST` and `$DB_PASSWORD` are then available to every command in `phases:`.

    > **Why `${var.user_id}` and not your own ID typed in?** The buildspec is a Terraform heredoc (`<<-EOF`, not `<<-'EOF'`), so Terraform interpolates `${var.user_id}` before CodeBuild ever sees it. Hardcoding works too, but the variable keeps this file identical for every student — the same reason the wrappers in Step 11 have nothing to edit.

    > **This uses the CodeBuild service role, not your IAM user.** The `env:` block is resolved by CodeBuild itself using `aws_iam_role.codebuild` from `lab3/pipeline/iam.tf`. That role grants `ssm:*` and `secretsmanager:GetSecretValue`. If you scope it down later, the `env:` block is the first thing to fail, before any build command runs.

21. **Export the values as `TF_VAR_*` so the plan picks them up**

    Still in the `plan_staging` buildspec, set the two Terraform variables from the CodeBuild env vars just before the plan runs:

    ```yaml
    phases:
      build:
        commands:
          - echo "=== Planning staging environment ==="
          - cd environments/staging
          - export TF_VAR_db_host="$DB_HOST"
          - export TF_VAR_db_password="$DB_PASSWORD"
          - terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="region=$BUCKET_REGION"
          - terraform plan -out=tfplan
          - echo "=== Staging plan complete ==="
    ```
    Terraform reads any `TF_VAR_<name>` environment variable as the value for `variable "<name>"`. **Leave the apply-stage buildspec exactly as it is** — `terraform apply -auto-approve tfplan` already carries these values inside the plan file.

22. **Declare and consume the variables in the staging wrapper**

    The variables have to be declared in the directory Terraform actually runs in, which is `environments/staging/`, not the repo root. Open `environments/staging/main.tf` in your `webapp-repo` clone and add:

    ```hcl
    variable "db_host" {
      description = "Database hostname injected from Parameter Store via the pipeline."
      type        = string
      default     = "unset"
    }

    variable "db_password" {
      description = "Database password injected from Secrets Manager via the pipeline."
      type        = string
      sensitive   = true
      default     = "unset"
    }

    # Proves the injection worked: check this parameter in the console after the
    # pipeline runs and you'll see the Parameter Store value that CodeBuild fetched.
    resource "aws_ssm_parameter" "db_config" {
      name  = "/${var.user_id}/staging/db-endpoint"
      type  = "String"
      value = var.db_host
    }
    ```
    Two things to notice:

    - **`sensitive = true`** keeps `db_password` out of `terraform plan` output and out of any plaintext output — Terraform prints `(sensitive value)` instead.
    - **The `default = "unset"`** matters. Plan-Production and the Validate stage run against code that has no `TF_VAR_db_*` set; without defaults those stages would fail with "No value for required variable."

23. **Re-apply the pipeline and push the wrapper changes**

    Apply the updated CodeBuild project so the new buildspec takes effect:

    ```bash
    cd ~/Advanced_Terraform/lab3/pipeline
    terraform apply
    ```
    Then commit and push your `webapp-repo` updates:

    ```bash
    cd ~/Advanced_Terraform/lab3/webapp-repo
    git add environments/staging/main.tf
    git commit -m "Consume pipeline-injected db_host and db_password in staging"
    git push origin main
    ```
24. **Verify in the Plan-Staging build log**

    In the browser, open the **plan-staging** build log. In the **Plan-Staging** box, click the action name **Terraform-Plan-Staging**. (Plan, not apply: the `env:` block you added lives in the plan project.)

    Look for this line near the top, before the first build command:

    ```
    [Container] ... Decrypting parameter store environment variables
    ```
    That line is the only confirmation the log gives. **CodeBuild does not print the resolved values**: not the Parameter Store hostname, and not the Secrets Manager password.

    Scroll down to the `terraform plan` output and find the parameter being created:

    ```
      # aws_ssm_parameter.db_config will be created
      + resource "aws_ssm_parameter" "db_config" {
          + name  = "/userXX/staging/db-endpoint"
          + value = (sensitive value)
        }

    Plan: 1 to add, 0 to change, 0 to destroy.
    ```

    > **Why is `value` redacted when you only marked `db_password` sensitive?** The AWS provider declares `aws_ssm_parameter.value` sensitive in its own schema, so Terraform hides it whatever you assign. That is also why the plan can't confirm the injected hostname for you — the proof comes after the apply.

    Click **Overview** (top right) to return to the pipeline.

25. **Approve staging, then confirm the injected value**

    Your push in Step 23 started a new pipeline run, so the pipeline is waiting at **Approve-Staging** again.

    1. In the **Approve-Staging** box, click the action name **Approve-Staging-Deploy**
    2. In the **Review** dialog, select **Approve** under **Decision**
    3. Comment: "Reviewed plan - adds db-endpoint parameter from injected values"
    4. Click **Submit**

    Wait for **Apply-Staging** to finish.

    Now switch back to your **EC2 instance** and read the parameter the pipeline created:

    ```bash
    aws ssm get-parameter --name "/${STUDENT}/staging/db-endpoint" \
        --query 'Parameter.Value' --output text --region us-east-1
    ```
    > **Why us-east-1 and not the region you are working in?** That parameter is created by the
    > *staging wrapper*, so it lands wherever staging deploys. The `/lab3/db_host` parameter you
    > created by hand in Step 18 is in your primary region. Two parameters, two regions, and the
    > `--region` flag is the only thing telling them apart.
    **Expected:**

    ```
    rds.userXX.example.com
    ```
    That is the value you stored in Parameter Store in Step 18: CodeBuild fetched it, Terraform received it as `TF_VAR_db_host`, and the apply wrote it into a real resource.

    > **`ParameterNotFound`?** Apply-Staging has not finished. The parameter is created by the apply, not the plan. Check the pipeline and wait for the **Apply-Staging** box to go green, then re-run the command.

    > **In production, scope tighter.** The CodeBuild role in `lab3/pipeline/iam.tf` grants `ssm:*` and `secretsmanager:GetSecretValue` on `*`. For real workloads, scope `secretsmanager:GetSecretValue` to the specific secret ARN and `ssm:GetParameter*` to the specific parameter path prefix. Use `aws:ResourceTag` condition keys to limit by environment.

---

## Task 6: Promote to Production (10 min)

26. **Review Production Plan**

    After staging apply completes, the pipeline automatically runs **Plan-Production**:

    1. In the **Plan-Production** box, click the action name **Terraform-Plan-Prod**
    2. The **Logs** tab opens on the CodeBuild output
    3. Verify it's creating the same 7 resources in **us-west-2**

27. **Approve Production Deployment**

    When pipeline reaches **Approve-Production**:

    1. In the **Approve-Production** box, click the action name **Approve-Production-Deploy**
    2. In the **Review** dialog, select **Approve** under **Decision**
    3. Comment: "Staging verified. Approving production deployment to us-west-2"
    4. Click **Submit**

    Watch **Apply-Production** execute.

28. **Verify Production Deployment**

    Same flow as Step 17, but reading from the prod state key (`pipeline/prod/...`):

    ```bash
    aws s3 cp s3://userXX-terraform-state-SUFFIX/pipeline/prod/terraform.tfstate - --region <bucket-region> | \
        jq -r '.outputs.public_ip.value'
    ```
    Then curl the prod web server:

    ```bash
    curl http://<PROD_PUBLIC_IP>
    ```
    **Expected output:**

    ```html
    <h1>Sample Web App</h1>
    <p>Environment: prod</p>
    <p>User: userXX</p>
    <p>Deployed via CI/CD Pipeline</p>
    ```

    Same content as staging, only the `Environment` line differs.

    **Then confirm both environments in the console.** Switch the region picker to **us-east-1**,
    then **us-west-2**, and in each one filter EC2 → Instances and VPC → Your VPCs by tag
    `User = userXX`. Every resource the pipeline built carries that tag, which is how you find your
    own work in a shared account.

---

## Challenge: Promote to Serverless (optional, ~15 min)

Everything this needs is already in the repo. It is optional — if you are short on time, go
straight to Task 7 and clean up.

`app-repo/` ships a second module, `modules/app-serverless/`, that accepts the same inputs as
`modules/app/` and exposes the same outputs, with `api_url` populated instead of `public_ip`.
Because the two share an interface, swapping the deployed payload from EC2 to Lambda + API Gateway
is one line per environment — and the pipeline does not change at all.

**Part 1 — swap both environments.**

In `~/Advanced_Terraform/lab3/webapp-repo`, change exactly one line in
`environments/staging/main.tf`:

```diff
  module "app" {
-   source      = "../../modules/app"
+   source      = "../../modules/app-serverless"
    user_id     = var.user_id
    environment = "staging"
  }
```
Make the same change in `environments/prod/main.tf`, then commit and push:

```bash
git add environments/staging/main.tf environments/prod/main.tf
git commit -m "Switch app module to Lambda + API Gateway"
git push origin main
```

The pipeline triggers automatically. The plan shows roughly **7 to destroy** (VPC, subnet, IGW, RT,
RTA, SG, EC2) and **~8 to add** (IAM role and policy attachment, log group, Lambda function, API,
integration, route, stage, permission). Approve both gates.

**Part 2 — verify the new endpoint.**

`api_url` replaces `public_ip` in the new state:

```bash
aws s3 cp s3://userXX-terraform-state-SUFFIX/pipeline/staging/terraform.tfstate - --region <bucket-region> | \
    jq -r '.outputs.api_url.value'

curl <staging api_url>
```

**Expected:**

```html
<h1>Sample Web App (Serverless)</h1>
<p>Environment: staging</p>
<p>User: userXX</p>
<p>Deployed via Lambda + API Gateway HTTP API</p>
```

Repeat for prod using `pipeline/prod/terraform.tfstate`.

> **What this demonstrates.** The Plan-Staging, Apply-Staging, Plan-Production and
> Apply-Production stages ran identically — only the resources they manage changed. That is the
> payoff of designing a module interface around a stable contract rather than the technology
> behind it.

## Task 7: Cleanup (5 min)

29. **Destroy both environments**

    **The pipeline cannot do this.** Its eight stages are Source, Validate, Plan-Staging,
    Approve-Staging, Apply-Staging, Plan-Production, Approve-Production, Apply-Production — there
    is no destroy stage, and a pipeline that could destroy production on a push is a pipeline
    nobody should build. Tear down from the CLI instead.

    ```bash
    # Destroy staging
    cd ~/Advanced_Terraform/lab3/webapp-repo/environments/staging
    terraform init -backend-config="bucket=<your Lab 1 state bucket>" -backend-config="region=<your bucket region>"
    terraform destroy -auto-approve

    # Destroy production
    cd ~/Advanced_Terraform/lab3/webapp-repo/environments/prod
    terraform init -backend-config="bucket=<your Lab 1 state bucket>" -backend-config="region=<your bucket region>"
    terraform destroy -auto-approve
    ```

30. **Verify Cleanup**

    Verify no instances remain (regardless of whether you ran the bonus or stayed on EC2):

    ```bash
    # EC2 instances tagged with your user ID — should return empty after destroy.
    aws ec2 describe-instances \
        --filters "Name=tag:User,Values=userXX" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output table \
        --region us-east-1

    aws ec2 describe-instances \
        --filters "Name=tag:User,Values=userXX" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output table \
        --region us-west-2
    ```
    If you ran the Bonus task and deployed Lambda/API Gateway instead, also confirm those are gone:

    ```bash
    aws lambda list-functions --region us-east-1 --query 'Functions[?starts_with(FunctionName, `userXX-`)].FunctionName' --output text
    aws lambda list-functions --region us-west-2 --query 'Functions[?starts_with(FunctionName, `userXX-`)].FunctionName' --output text
    ```
    Both should return empty after destroy.

31. **Delete the Task 5 secret and parameter**

    These were created by CLI, not Terraform, so `terraform destroy` does not remove them.

    ```bash
    # $STUDENT was exported in Step 18
    aws secretsmanager delete-secret         --secret-id "${STUDENT}/lab3/db_password"         --force-delete-without-recovery

    aws ssm delete-parameter --name "/${STUDENT}/lab3/db_host"
    ```

---

## Lab Complete!

You have successfully:

- Deployed a CI/CD pipeline for Terraform
- Pushed **real infrastructure** (VPC + EC2) through the pipeline
- Deployed to **staging (us-east-1)** and verified
- Injected config and a credential at plan time, without either reaching source control
- Approved and promoted to **production (us-west-2)**
- Verified both environments with curl
- Tore both environments down from the CLI, and saw why the pipeline cannot do it

### Key Takeaways

| Concept | What You Experienced |
|---------|---------------------|
| **Golden Rule** | Plan saved as artifact, apply uses saved plan |
| **Multi-region deployment** | Same code deployed to us-east-1 and us-west-2, from a pipeline in us-east-2 |
| **Approval gates** | Manual review before each environment |
| **Student isolation** | All resources tagged with your AWS login ID |
| **Full lifecycle** | Create and verify through the pipeline; destroy from the CLI |

### Connection to Chapters

| Chapter | Lab Experience |
|--------|----------------|
| Chapter 1 (State) | Separate state per environment (staging/prod) |
| Chapter 2 (Import) | Contrast: Import is for existing infra; pipeline is for new infra |
| Chapter 3 (Pipeline) | Full implementation of the 8-stage pattern |

---

## Troubleshooting

### Pipeline Stuck on Source

CodeCommit polling runs about once a minute, so allow 1-2 minutes after a push — or click **Release change** in the pipeline console to start the run immediately.

> **Why polling and not an event?** A CodePipeline created through the console gets an EventBridge rule for push-triggering created for it automatically. One created through the API — which is what Terraform does — does not, and the API default for `PollForSourceChanges` is `false`. `lab3/pipeline/codepipeline.tf` sets it to `"true"` explicitly so pushes trigger the pipeline without a separate EventBridge rule and its IAM role. In production, prefer the EventBridge rule: it fires in seconds instead of up to a minute, and it doesn't spend a polling API call every minute.

### Apply Fails with "Saved plan is stale"

```
Error: Saved plan is stale
The given plan file can no longer be applied because the state was changed
by another operation after the plan was created.
```

Each push starts a pipeline execution, and an execution parked at an approval gate keeps its plan file from when the plan stage ran. If a different execution applies to the same environment in the meantime, the parked plan no longer matches the state and the apply refuses it.

This is easy to reach in this lab: Task 3's push and Task 5's push are two executions, and both queue at **Approve-Production**. Approving the older one after the newer one has already applied produces exactly this error.

To recover, run the newest execution instead of the parked one:

1. In the pipeline console, click **Release change** to start a fresh execution from the latest commit
2. Approve **Approve-Staging**, then **Approve-Production**, on that execution

Check which execution you are approving by matching the commit message shown in each stage box.

> **Why saved plans at all?** Applying a reviewed plan file is what makes the approval gate meaningful — the approver sees exactly what will be applied. The cost is that the plan can go stale, which is why production pipelines keep the window between plan and apply short.

### Validate Fails

```bash
terraform fmt -recursive
git add . && git commit -m "Fix formatting" && git push origin main
```
### Apply Fails with Permission Error

Check CodeBuild logs for the specific permission needed. The IAM role may need additional policies for EC2/VPC resources.

### Can't Find Your Resources

Filter by tag: `User = userXX` in the AWS console.

### EC2 Instance Not Accessible

1. Check security group allows HTTP (port 80)
2. Check route table has route to IGW
3. Verify instance is in "running" state

---

## Lab Completion Checklist

- [ ] Deployed pipeline infrastructure (~15 resources)
- [ ] Cloned the CodeCommit repository and pushed the application code
- [ ] Observed the pipeline trigger automatically
- [ ] Reviewed Plan-Staging output (7 resources) and approved
- [ ] Verified staging with curl (us-east-1)
- [ ] Stored a Parameter Store value and a Secrets Manager credential
- [ ] Injected both into the plan stage and confirmed the resulting parameter
- [ ] Reviewed Plan-Production output (7 resources) and approved
- [ ] Verified production with curl (us-west-2)
- [ ] Confirmed resources tagged with your AWS login ID in both regions
- [ ] Destroyed both environments and deleted the Task 5 secret and parameter

---


## End of Day: Complete Cleanup

```bash
# 1. Destroy web application (staging)
cd ~/Advanced_Terraform/lab3/webapp-repo/environments/staging
terraform init -backend-config="bucket=userXX-terraform-state-SUFFIX" -backend-config="region=<your-bucket-region>"
terraform destroy -auto-approve

# 2. Destroy web application (prod)
cd ~/Advanced_Terraform/lab3/webapp-repo/environments/prod
terraform init -backend-config="bucket=userXX-terraform-state-SUFFIX" -backend-config="region=<your-bucket-region>"
terraform destroy -auto-approve

# 3. Destroy pipeline infrastructure
cd ~/Advanced_Terraform/lab3/pipeline
terraform destroy -auto-approve

# 4. Verify no running instances
aws ec2 describe-instances \
    --filters "Name=tag:User,Values=userXX" "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text \
    --region us-east-1

aws ec2 describe-instances \
    --filters "Name=tag:User,Values=userXX" "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text \
    --region us-west-2
```
---

## Additional Resources

| Resource | URL |
|---|---|
| AWS CodePipeline | https://docs.aws.amazon.com/codepipeline/latest/userguide/ |
| AWS CodeBuild | https://docs.aws.amazon.com/codebuild/latest/userguide/ |
| Terraform CI/CD | https://developer.hashicorp.com/terraform/tutorials/automation |
| Multi-Region Deployment | https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform |
