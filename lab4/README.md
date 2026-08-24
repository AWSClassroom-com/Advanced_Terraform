# Lab 4: Auditing & Observability

> 📖 **Student instructions:** [`../labs/lab4.md`](../labs/lab4.md)
>
> The Terraform code in this folder is what students run during the lab; the step-by-step instructions live in the `labs/` folder at the repo root.

CloudWatch dashboard summarizing Terraform activity: CodeBuild build duration + success/failure, CodePipeline executions, S3 state bucket operations, S3 lockfile activity. Plus reference panels with Log Analytics query templates and quick links to relevant consoles.

## Subfolder

| Folder | Used for |
|--------|----------|
| [`observability/`](./observability/) | Single dashboard.tf creating `aws_cloudwatch_dashboard.terraform_ops` named `${var.user_id}-terraform-operations`. Standalone — does not depend on any other module's outputs (uses `var.state_bucket_name` directly so the S3 widgets always work regardless of bucket suffix). |

## What's different from a "standard" Terraform pipeline dashboard

The DynamoDB lock-table widget you'd find in older dashboards is **gone** — Lab 1 uses Terraform 1.10+ S3 native locking (`use_lockfile = true`), so there is no DynamoDB table to monitor. Replaced with an "S3 Lockfile Activity" widget that reads PutRequest metrics on the state bucket.

## Optional follow-up

To see only `.tflock` PutRequest activity (instead of bucket-wide), add an `aws_s3_bucket_metric` filter to `lab1/state-infra/main.tf`:

```hcl
resource "aws_s3_bucket_metric" "lockfile_activity" {
  bucket = aws_s3_bucket.terraform_state.id
  name   = "lockfile-activity"
  filter { prefix = "" }
}
```

S3 Request Metrics are ~$0.30 per million requests monitored — negligible for a lab.
