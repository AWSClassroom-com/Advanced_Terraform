# Lab 4 answers

Complete code for **Auditing & Observability**.

Nothing in Lab 4 asks you to write Terraform by hand — the dashboard configuration ships complete
and you supply values through `terraform.tfvars`. This folder is a reference copy so every lab has
one, and so you can diff if a widget does not render.

`observability/dashboard.tf` is the file to read. Its widgets are built on **CodeBuild** metrics
(`SucceededBuilds`, `FailedBuilds`, `Builds`, `Duration`) and **S3** request metrics
(`GetRequests`, `PutRequests`) on the state bucket.

There are no CodePipeline widgets, and the comments in the file explain why: CodePipeline publishes
only `PipelineDuration` and `FailedPipelineExecutions`, and only for V2 pipelines. There is no
pipeline success metric at any pipeline type, so "did the apply succeed" has to be answered from
CodeBuild.
## Challenge — catch a manual change

No files change; the dashboard code IS the answer key, which is the point.

```bash
cd ~/Advanced_Terraform/lab4/observability

# after moving/resizing a widget in the CloudWatch console and saving:
terraform plan -detailed-exitcode; echo $?    # 2 - changes present: drift
terraform apply                               # the code restores the dashboard
terraform plan -detailed-exitcode; echo $?    # 0 - clean again
```

Exit codes for `-detailed-exitcode`: `0` no changes, `1` error, `2` changes present. A scheduled
drift check wants exactly that split — "there is work" has to fail loudly, which is why the
unguarded form belongs after apply, not in a plan stage.

**Part 2 — the identities on `PutDashboard`:**

| Event | `userIdentity.type` | Who it names |
|---|---|---|
| Your console Save | `IAMUser` | `arn:...:user/userXX` — the person, directly |
| Your `terraform apply` (create, and the revert) | `AssumedRole` | `assumed-role/Terraform-InstanceRole/i-<instance-id>` — the EC2 instance profile, NOT your IAM user |

The **third** identity, `assumed-role/userXX-codebuild-terraform-role/...`, never appears on
`PutDashboard` — the pipeline has never touched the dashboard. It shows up on the Lab 3 events
Task 2 queried. Three ways the same account says "who": the person, the machine the person used,
and the pipeline nobody touched at all.
