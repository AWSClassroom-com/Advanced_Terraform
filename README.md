# Advanced Terraform — Lab Code

Terraform code for the four hands-on labs in **Advanced Terraform on AWS** (Day 3 of the Hands-On Terraform series). Students deploy each lab's infrastructure with `terraform init`/`plan`/`apply` instead of typing every resource by hand.

This is a **companion** to the Day 1-2 [hands-on-terraform](https://github.com/AWSClassroom-com/hands-on-terraform) repo. Day 3 assumes the Day 1-2 stack is already running: state bucket, VPC, security group, and the EC2 deploy server.

## 📖 Start here — student instructions

The numbered step-by-step lab walkthroughs live in [**`labs/`**](./labs/), one Markdown file per lab:

- [`labs/lab1.md`](./labs/lab1.md) — Multi-Environment State Strategy
- [`labs/lab2.md`](./labs/lab2.md) — Import Day 1-2 Infrastructure
- [`labs/lab3.md`](./labs/lab3.md) — Pipeline Operations
- [`labs/lab4.md`](./labs/lab4.md) — Auditing & Observability

The top-level `lab1/`, `lab2/`, `lab3/`, `lab4/` folders contain the Terraform **code** each lab applies. Each of those folders has its own `README.md` describing the code structure; the actual lab walkthrough you should follow is in `labs/`.

## Labs

| Lab | Folder | What it covers |
|-----|--------|----------------|
| **Lab 1** | [`lab1/`](./lab1/) | Multi-Environment State Strategy: workspaces, safety guards, cross-state dependencies, directory pattern |
| **Lab 2** | [`lab2/`](./lab2/) | Importing existing infrastructure: bring Day 1-2 VPC + SG under remote-state Terraform management |
| **Lab 3** | [`lab3/`](./lab3/) | Pipeline Operations: CodePipeline + CodeBuild + multi-region promotion (staging → prod) |
| **Lab 4** | [`lab4/`](./lab4/) | Auditing & Observability: CloudTrail queries + CloudWatch dashboard for Terraform activity |

## Folder layout

```
Advanced_Terraform/
├── lab1/
│   ├── state-infra/         workspaces + safety guards
│   ├── networking/          shared VPC for terraform_remote_state demo
│   └── directories/         module + dev/ + staging/ (directory pattern)
├── lab2/
│   ├── day1-vpc-lean/       fallback if Day 1-2 VPC was destroyed
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
- **`var.account`:** student's IAM username (e.g. `user01`). No format validation.
- **`var.region`:** no default — passed in via `terraform.tfvars`.
- **State backend:** `providers.tf` keeps `bucket` and `region` out of the file; passed at init time:
  ```bash
  terraform init \
      -backend-config="bucket=tf-state-userxx-XXXXXXXX" \
      -backend-config="region=us-east-2"
  ```
- **Tags:** every resource gets a `Name` tag prefixed with `${var.account}-`.

## Per-module setup

```bash
cd "lab<N>/<module>/"
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

## Day 1-2 stack assumed (matters for Lab 2)

By the time students reach Lab 2, they should have running from Days 1-2:

- S3 state bucket: `tf-state-${var.account}-<random>` with `object_lock_enabled = true`
- VPC: `${var.account}-vpc` (192.168.0.0/20) + public subnet + IGW + NAT GW + RT + RT assoc
- Security group: `${var.account}-allow-http-ssh` with three modern rule resources
- Deploy EC2: `deploy-${var.account}` (created via console)

If the VPC + SG were destroyed at end of class, Lab 2's `lab2/day1-vpc-lean/` lets students redeploy without NAT Gateway cost.
