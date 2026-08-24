# Lab 1 answers

Complete code for **Multi-Environment State Strategy**, including the Challenge.

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
