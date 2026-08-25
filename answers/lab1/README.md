# Lab 1 answers

Complete code for **Multi-Environment State Strategy**, including the Challenges.

Everything except the two files below is identical to what ships in `lab1/`.

| File | What differs |
|---|---|
| `networking/outputs.tf` | **Challenge Part 2** — adds a `public_subnet_cidr` output. This is the two-sided half: the output has to be declared and `lab1/networking` applied *before* the application state can read it. |
| `state-infra/main.tf` | **Challenge Part 1 and 2** — two new locals reading `vpc_cidr` and `public_subnet_cidr` from the networking state, both carried into the `app-config` parameter. |

## The part worth reading

The Challenge asks why your first `terraform apply` reports **no change** to the parameter. The
answer is in the resource's own `lifecycle` block:

```hcl
lifecycle {
  ignore_changes = [value]
}
```

`ignore_changes` on `value` tells Terraform to ignore the entire attribute, so adding a key to the
`jsonencode` block produces no diff. It was there because `deployed_at = timestamp()` changes on
every plan and would otherwise leave the resource permanently dirty.

This answer drops `deployed_at` and empties `ignore_changes`, so a genuine contract change shows up
as a genuine diff. Keeping `ignore_changes` and forcing the update with
`terraform apply -replace=aws_ssm_parameter.app_config[0]` also works.

## Verify

```bash
aws ssm get-parameter --name "/<your user_id>/dev/app-config" \
    --query 'Parameter.Value' --output text
```
Both CIDR blocks should appear in the JSON.
## Challenge 2 — the ephemeral feature workspace

No files change for this one; it is a command sequence. From `lab1/state-infra`:

```bash
# Part 1 - the guard says no
terraform workspace new hotfix
terraform plan                       # fails: Workspace 'hotfix' is not allowed
terraform workspace select dev
terraform workspace delete hotfix

# Part 2 - full lifecycle of a compliant workspace
BUCKET=$(terraform output -raw state_bucket_name)
terraform workspace new feature-demo
terraform apply -refresh-only -auto-approve   # materializes the state file, creates nothing
aws s3 ls "s3://$BUCKET/env:/" --recursive    # env:/feature-demo/... listed

terraform workspace select dev
terraform workspace delete feature-demo       # empty state deletes cleanly
aws s3 ls "s3://$BUCKET/env:/" --recursive    # feature-demo object gone
```

`workspace delete` refuses the workspace you are standing in, and refuses a non-empty state
without `-force`. The empty state deletes cleanly and removes its S3 object with it — the whole
environment existed and vanished without a single resource being created.
