# Lab 3: Pipeline Operations

> 📖 **Student instructions:** [`../labs/lab3.md`](../labs/lab3.md)
>
> The Terraform code in this folder is what students run during the lab; the step-by-step instructions live in the `labs/` folder at the repo root.

CI/CD pipeline for Terraform: CodePipeline + CodeBuild + manual approval gates + multi-region promotion (staging → prod).

## Subfolders

| Folder | Used for |
|--------|----------|
| [`pipeline/`](./pipeline/) | The pipeline infrastructure itself: CodeCommit repo, CodeBuild projects (validate, plan-staging, apply-staging, plan-prod, apply-prod), CodePipeline with 8 stages, IAM roles. Deploy this once. |
| [`app-repo/`](./app-repo/) | The Terraform code that gets pushed THROUGH the pipeline. `modules/app/` is the reusable web-app module; `environments/staging/` and `environments/prod/` are the per-environment callers. |

## Order of operations

1. `cd pipeline/` — deploy the pipeline (CodeCommit + CodeBuild + CodePipeline + IAM, ~15 resources)
2. Capture the `repository_clone_url_http` and `pipeline_url` outputs
3. `cd ../app-repo/` — copy these files into a clone of the empty CodeCommit repo
4. Push to CodeCommit — pipeline triggers on `git push`
5. Watch validate → plan-staging → approve → apply-staging → plan-prod → approve → apply-prod
6. Verify the web app loads in both regions

## The Golden Rule

The pipeline saves the plan as an artifact and applies the SAVED plan in a later stage:

```bash
# In plan stages:
terraform plan -out=tfplan

# In apply stages (uses the saved artifact, never re-plans):
terraform apply -auto-approve tfplan
```

This guarantees the plan that was reviewed/approved is the plan that runs.
