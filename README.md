# Advanced Terraform — Lab Code

Terraform code for the four hands-on labs in **Advanced Terraform on AWS** (Day 3 of the Hands-On Terraform series). Students deploy each lab's infrastructure with `terraform init`/`plan`/`apply` instead of typing every resource by hand.

This is a **companion** to the Day 1-2 [hands-on-terraform](https://github.com/AWSClassroom-com/hands-on-terraform) repo. Day 3 carries the knowledge forward but not the infrastructure — it builds everything it needs, starting from an empty account.

## 📖 Start here — student instructions

The numbered step-by-step lab walkthroughs live in [**`labs/`**](./labs/), one Markdown file per lab:

- [`labs/lab1.md`](./labs/lab1.md) — Multi-Environment State Strategy
- [`labs/lab2.md`](./labs/lab2.md) — Import Existing Infrastructure
- [`labs/lab3.md`](./labs/lab3.md) — Pipeline Operations
- [`labs/lab4.md`](./labs/lab4.md) — Auditing & Observability

The top-level `lab1/`, `lab2/`, `lab3/`, `lab4/` folders contain the Terraform **code** each lab applies. Each of those folders has its own `README.md` describing the code structure; the actual lab walkthrough you should follow is in `labs/`.

## Labs

| Lab | Folder | What it covers |
|-----|--------|----------------|
| **Lab 1** | [`lab1/`](./lab1/) | Multi-Environment State Strategy: workspaces, safety guards, cross-state dependencies, directory pattern |
| **Lab 2** | [`lab2/`](./lab2/) | Importing existing infrastructure: bring an unmanaged VPC + SG under remote-state Terraform management |
| **Lab 3** | [`lab3/`](./lab3/) | Pipeline Operations: CodePipeline + CodeBuild + multi-region promotion (staging → prod) |
| **Lab 4** | [`lab4/`](./lab4/) | Auditing & Observability: CloudTrail queries + CloudWatch dashboard for Terraform activity |

Complete working code for every lab, including all challenges, is in [**`answers/`**](./answers/) — one folder per lab. Try the lab first.

## Folder layout

```
Advanced_Terraform/
├── lab1/
│   ├── state-infra/         workspaces + safety guards
│   ├── networking/          shared VPC for terraform_remote_state demo
│   └── directories/         module + dev/ + staging/ (directory pattern)
├── lab2/
│   ├── existing-stack/       the stack Lab 2 imports (local state)
│   └── import/              9-resource import target (VPC + SG/rules)
├── lab3/
│   ├── pipeline/            CodePipeline + CodeBuild + IAM
│   └── app-repo/            web-app Terraform pushed through the pipeline
└── lab4/
    └── observability/       CloudWatch dashboard for pipeline + state activity
```

## Conventions

- **AWS provider:** `~> 6.0`
- **Terraform:** `>= 1.10.0` (S3 native locking via `use_lockfile = true`)
- **`var.user_id`:** the student's AWS login ID (e.g. `user07`), validated against `^user[0-9]{2}$`.
- **Regions:** `var.primary_region` (where the student works, default `us-east-2`), `var.staging_region` (Lab 3 staging, `us-east-1`), `var.prod_region` (Lab 3 prod, `us-west-2`), `var.bucket_region` (where the state bucket lives). All set in `terraform.tfvars`; nothing hardcodes a region.
- **State backend:** `providers.tf` keeps `bucket` and `region` out of the file; passed at init time:
  ```bash
  terraform init \
      -backend-config="bucket=tf-state-userxx-XXXXXXXX" \
      -backend-config="region=us-east-2"
  ```
- **Tags:** every resource gets a `Name` tag prefixed with `${var.user_id}-`.

### Pinned tool versions

The Lab 3 pipeline installs two tools into every CodeBuild container, both pinned in
`lab3/pipeline/variables.tf`:

| Variable | Default | Why it is pinned |
|---|---|---|
| `terraform_version` | `1.15.9` | Plan and Apply run in separate containers with a human approval between them. If each installed "latest", a release landing in that window makes Apply a different version from Plan, and a saved plan file cannot be read across versions. |
| `tflint_version` | `0.64.0` | The upstream `install_linux.sh` is being withdrawn on 1 September 2026. A build that pipes it stops working on that date. |

**Being behind is fine; being *unknowingly* behind is not.** Old Terraform and tflint
releases stay downloadable indefinitely, so a stale pin keeps working — it just drifts from
what `yum install terraform` puts on the student's VM. Check both before a cohort:

```bash
grep -A12 'variable "terraform_version"' lab3/pipeline/variables.tf | grep default
curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep '"tag_name"'

grep -A12 'variable "tflint_version"' lab3/pipeline/variables.tf | grep default
curl -s https://api.github.com/repos/terraform-linters/tflint/releases/latest | grep '"tag_name"'
```

Bumping is a one-line edit to each default. Nothing else references either version.

## Per-module setup

```bash
cd lab<N>/<module>/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your account, region, and any IDs the module needs

terraform init \
    -backend-config="bucket=tf-state-userxx-XXXXXXXX" \
    -backend-config="region=us-east-2"

terraform plan
terraform apply
```

Cleanup:
```bash
terraform destroy
```

## Required AWS permissions

Students need a broad lab IAM policy. The companion course materials include `lab_required_permissions.json` listing all `<service>:*` permissions detected from this code (13 services: autoscaling, cloudtrail, cloudwatch, codebuild, codecommit, codepipeline, ec2, elasticloadbalancing, iam, logs, s3, ssm, sts). **Sandbox use only — never apply to production.**

## What Day 3 builds for itself

Day 3 starts from an empty AWS account. Nothing from Days 1-2 has to be running:

- **Deploy EC2 instance** — Lab 1 Task 1 launches it (`deploy-<user_id>`, t3.small, Amazon Linux 2023,
  instance profile `Terraform-InstanceRole`).
- **S3 state bucket** — `lab1/state-infra` creates it (`<user_id>-terraform-state-<random>`, versioned
  and encrypted). Locking is Terraform 1.10+ S3 native locking, so there is no DynamoDB table and no
  Object Lock.
- **VPC + security group** — `lab2/existing-stack` deploys them with **local state** in Lab 2 Task 1,
  so they stand in for infrastructure that exists outside any remote state. Lab 2 then imports them.

What does carry over from Days 1-2 is knowledge, not resources: workspaces, remote state, the
`-backend-config` init pattern, import blocks, and modules.
