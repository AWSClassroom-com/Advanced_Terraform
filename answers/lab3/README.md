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
## Challenge — the linter in the Validate stage

`pipeline/codebuild.tf` in this answers tree carries the finished buildspec: tflint installed in
the `install` phase, run against both environment wrappers at the end of the `build` phase with
`--call-module-type=none` so the lint stays scoped to the wrapper directory.

The first run fails on purpose: `db_password` in the staging wrapper is declared and never
consumed — it is injected by the pipeline and exists only to be baked into the plan. Deleting it
would break Task 5, so the fix is the annotation this tree carries in
`app-repo/environments/staging/main.tf`:

```hcl
# tflint-ignore: terraform_unused_declarations  # injected by the pipeline; plan-time only
```

That is the enterprise pattern in miniature: adopt a linter, hit a finding on code that is right
for a reason the linter cannot see, and record the reason at the finding site instead of turning
the rule off.

> Not yet verified on the lab VM — confirm the tflint install and both lint runs during the
> end-to-end lab pass before shipping.
