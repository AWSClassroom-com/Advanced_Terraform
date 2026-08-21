# Lab 1: State Backend Setup & Locking — Solution

This directory contains the complete solution for Lab 1 of Terraform Day 3.

## Directory Structure

```
lab1/state-infra/
├── providers.tf              # AWS/random/time providers + commented backend block
├── variables.tf              # user_id, primary_region, bucket_region, state_bucket_name
├── main.tf                   # S3 state bucket, locking demo, Part D cross-state
├── workspace_guard.tf        # null_resource preconditions blocking bad workspaces
├── outputs.tf                # state_bucket_name and the Part D outputs
├── terraform.tfvars.example  # Copy to terraform.tfvars and fill in
└── README.md                 # This file
```

## Deployment Steps

### Part A: Initial Deployment (Local State)

1. **Set your AWS login ID** in `terraform.tfvars`:
   ```hcl
   user_id = "user07"   # your assigned AWS login ID
   account    = "user07"   # same value; used by Part D
   ```
   `user_id` is validated against `^user[0-9]{2}$` — the placeholder `userXX` is rejected on purpose.

2. **Select a workspace, then deploy**:
   ```bash
   terraform init
   terraform workspace new dev
   terraform apply
   ```

   `workspace_guard.tf` blocks the `default` workspace, so `terraform workspace new dev` is required before the first apply.

   This creates:
   - S3 bucket with versioning, AES256 encryption, and public access blocking
   - A `time_sleep` resource and an SSM parameter for the locking demo
   - No DynamoDB table — Day 3 uses Terraform 1.10+ S3 native locking (`use_lockfile = true`)

3. **Capture the bucket name** — every other lab needs it:
   ```bash
   terraform output state_bucket_name
   # e.g. user07-terraform-state-x8k2m4
   ```
   The random 6-character suffix guarantees the name is globally unique, so no two students collide.

### Part B: Migrate to Remote State

1. **Uncomment the backend block** in `providers.tf` and paste in the bucket name from Part A. The key is `lab1-app/terraform.tfstate`.

2. **Re-initialize to migrate state**:
   ```bash
   terraform init -migrate-state
   ```
   When prompted "Do you want to copy existing state to the new backend?", type `yes`.

3. **Verify migration** — workspaces write under an `env:/` prefix:
   ```bash
   aws s3 ls "s3://$(terraform output -raw state_bucket_name)/" --recursive
   # expect env:/dev/lab1-app/terraform.tfstate
   ```

### Part C: Test State Locking

1. **Open two terminal windows** in this directory.

2. **In Terminal 1**, start an apply. `time_sleep.locking_demo` holds the lock for 30 seconds:
   ```bash
   terraform apply -auto-approve
   ```

3. **In Terminal 2** (immediately), try to plan:
   ```bash
   terraform plan
   ```
   You should see a lock error naming who holds the lock and when they acquired it.

4. **View the lock object.** S3 native locking writes a `.tflock` file next to the state file — there is no DynamoDB table to scan:
   ```bash
   aws s3 ls "s3://$(terraform output -raw state_bucket_name)/env:/dev/lab1-app/"
   # terraform.tfstate.tflock appears only while a lock is held
   ```

5. **Wait for Terminal 1 to complete**, then retry Terminal 2.

### Part D: Cross-State Dependency

Set `state_bucket_name` in `terraform.tfvars` **after** `lab1/networking` has been deployed. Until it is set, the `terraform_remote_state` data source and the `app_config` parameter are gated off by `count` and Part A applies unchanged.

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| S3 Bucket | `<user_id>-terraform-state-<random6>` | Stores Terraform state files |
| S3 Versioning | (on bucket) | Preserves state file history |
| S3 Encryption | (on bucket) | AES256 encryption at rest |
| S3 Public Access Block | (on bucket) | Prevents public access |
| SSM Parameter | `/<user_id>/lab1/lock-demo` | Demo resource for the locking test |
| Time Sleep | (30 seconds) | Creates the delay the locking demo needs |
| Null Resource | `workspace_guard` | Preconditions rejecting invalid workspaces |
| SSM Parameter | `/<account>/<workspace>/app-config` | Part D only — gated on `state_bucket_name` |

## Verification Commands

```bash
BUCKET=$(terraform output -raw state_bucket_name)

# Verify the bucket and its protections
aws s3api head-bucket --bucket "$BUCKET"
aws s3api get-bucket-versioning --bucket "$BUCKET"
aws s3api get-bucket-encryption --bucket "$BUCKET"
aws s3api get-public-access-block --bucket "$BUCKET"

# List state files across all workspaces
aws s3 ls "s3://$BUCKET/" --recursive

# Check Terraform state
terraform state list
terraform state show aws_s3_bucket.terraform_state
```

## Important Notes

- **Use your real IAM username** (`userNN`) everywhere — the validator rejects the `userXX` placeholder, and Labs 3 and 4 key their resource names off this same value
- The backend block is **commented out initially** so the bucket can be created before anything points at it
- After migration, the local `terraform.tfstate` retains only backend metadata
- Do **not** destroy the state bucket — Labs 2-4 use it
- Use `terraform force-unlock <LOCK_ID>` only when you are certain no apply is running

## Cost

All resources cost less than $0.01 for the entire lab:
- S3: ~$0.00 (state files are KB-sized)
- SSM Parameters: Free (standard tier)
