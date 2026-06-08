# Lab 1: Multi-Environment State Strategy

> 📖 **Student instructions:** [`../labs/lab1.md`](../labs/lab1.md)
>
> The Terraform code in this folder is what students run during the lab; the step-by-step instructions live in the `labs/` folder at the repo root.

Workspaces, safety guards, cross-state dependencies, and the directory-vs-workspace decision.

## Subfolders

| Folder | Used for |
|--------|----------|
| [`state-infra/`](./state-infra/) | Lab 1 Tasks 1-3: workspace fundamentals + safety guards (preconditions in a `null_resource.workspace_guard`) that block applies in unintended workspaces |
| [`networking/`](./networking/) | Lab 1 Task 3: shared VPC + IGW + subnet + RT + shared SG. Outputs `vpc_id`, `subnet_id`, `security_group_id` for downstream consumers via `terraform_remote_state` |
| [`directories/`](./directories/) | Lab 1 Task 4: directory pattern (`modules/app/` + `dev/` + `staging/`) — the alternative to workspaces |

## Order of operations

1. `state-infra/` — create dev/staging/prod workspaces, see safety guards reject `default` workspace
2. `networking/` — deploy the shared "networking team" VPC (separate state under same bucket)
3. `state-infra/` again — switch to dev workspace, deploy the application that reads networking outputs via `terraform_remote_state`
4. `directories/` — repeat the deployment using directory pattern; compare the two

State paths used:
- `state-infra/`: `lab1-app/terraform.tfstate` (workspace prefix `env:/<workspace>/` added automatically)
- `networking/`: `networking/terraform.tfstate` (no workspace — networking is shared)
- `directories/`: `directories/dev/terraform.tfstate` and `directories/staging/terraform.tfstate`

All under the same Day 2 Lab 3 bucket.
