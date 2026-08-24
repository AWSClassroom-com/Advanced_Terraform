# Lab 3 answers

Complete code for **Pipeline Operations**.

| File | What differs |
|---|---|
| `pipeline/codebuild.tf` | **Steps 23 and 24** — the `plan_staging` buildspec gains an `env:` block pulling `DB_HOST` from Parameter Store and `DB_PASSWORD` from Secrets Manager, and exports both as `TF_VAR_*` before `terraform plan` runs. |

Everything else is identical to what ships in `lab3/`.

## Why the plan stage and not the apply stage

`terraform apply tfplan` runs against a **saved plan file**, and Terraform refuses variables
alongside a saved plan:

```
Error: Can't set variables when applying a saved plan file
```

A saved plan already contains the variable values that were set when it was created. So the secrets
have to resolve at plan time and be baked into `tfplan`.

## One difference from the lab text

The lab tells you to replace `userXX` with your own login ID. This answer uses `${var.user_id}`
instead:

```yaml
env:
  parameter-store:
    DB_HOST: /${var.user_id}/lab3/db_host
```

That interpolates because the buildspec heredoc is `<<-EOF` rather than `<<-'EOF'`. Both work; the
variable form is what lets one file serve every student without edits.
