# Lab 1: State Backend Setup & Locking - Solution

This directory contains the complete solution for Lab 1 of Terraform Day 3.

## Directory Structure

```
lab1-state-infra/
├── providers.tf          # AWS and Time provider configuration with backend block
├── main.tf              # S3 bucket, DynamoDB table, and locking demo resources
├── outputs.tf           # Outputs for bucket name, table name, and backend config
├── terraform.tfvars     # Student ID variable value
└── README.md           # This file
```

## Deployment Steps

### Part A: Initial Deployment (Local State)

1. **Update your student ID** in `terraform.tfvars`:
   ```hcl
   student_id = "student01"  # Replace with your actual ID
   ```

2. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   This creates:
   - S3 bucket with versioning, encryption, and public access blocking
   - DynamoDB table for state locking
   - SSM parameter for locking demo (with 30-second delay)

### Part B: Migrate to Remote State

1. **Uncomment the backend block** in `providers.tf`:
   - Remove the `#` from lines 7-13
   - Update `studentXX` to match your student ID

2. **Re-initialize to migrate state**:
   ```bash
   terraform init
   ```
   
   When prompted "Do you want to copy existing state to the new backend?", type `yes`.

3. **Verify migration**:
   ```bash
   # Check state file exists in S3
   aws s3 ls s3://studentXX-terraform-state/platform/state-infra/
   
   # Verify state operations work
   terraform state list
   ```

### Part C: Test State Locking

1. **Open two terminal windows** in this directory

2. **In Terminal 1**, start an apply (holds lock for ~30 seconds):
   ```bash
   terraform apply -auto-approve
   ```

3. **In Terminal 2** (immediately), try to run a plan:
   ```bash
   terraform plan
   ```
   
   You should see a lock error with details about who holds the lock.

4. **View the lock in DynamoDB**:
   ```bash
   aws dynamodb scan --table-name studentXX-terraform-lock
   ```

5. **Wait for Terminal 1 to complete**, then retry Terminal 2.

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| S3 Bucket | `studentXX-terraform-state` | Stores Terraform state files |
| S3 Versioning | (on bucket) | Preserves state file history |
| S3 Encryption | (on bucket) | AES256 encryption at rest |
| S3 Public Access Block | (on bucket) | Prevents public access |
| DynamoDB Table | `studentXX-terraform-lock` | Provides state locking |
| SSM Parameter | `/studentXX/lab1/lock-demo` | Demo resource for locking test |
| Time Sleep | (30 seconds) | Creates delay for locking demo |

## Verification Commands

```bash
# Verify S3 bucket
aws s3api head-bucket --bucket studentXX-terraform-state
aws s3api get-bucket-versioning --bucket studentXX-terraform-state
aws s3api get-bucket-encryption --bucket studentXX-terraform-state
aws s3api get-public-access-block --bucket studentXX-terraform-state

# Verify DynamoDB table
aws dynamodb describe-table --table-name studentXX-terraform-lock

# List state files
aws s3 ls s3://studentXX-terraform-state/ --recursive

# Check Terraform state
terraform state list
terraform state show aws_s3_bucket.terraform_state
```

## Important Notes

- **Replace `studentXX`** with your actual student ID in all files
- The backend block is **commented out initially** to allow bootstrap deployment
- After migration, local `terraform.tfstate` becomes empty (only metadata remains)
- Do **not** destroy these resources - they're needed for Labs 2-4
- Use `terraform force-unlock <LOCK_ID>` only when absolutely certain no apply is running

## Cost

All resources cost less than $0.01 for the entire lab:
- S3: ~$0.00 (state files are KB-sized)
- DynamoDB: ~$0.00 (PAY_PER_REQUEST with minimal operations)
- SSM Parameters: Free (standard tier)
