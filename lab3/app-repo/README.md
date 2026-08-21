# lab3-app-repo (LabForge repo addition)

These files **replace** the contents of `lab3/app-repo/` in the GitHub repo `AWSClassroom-com/Advanced_Terraform`. They restore the VPC + EC2 + Apache pattern that Lab 3 narrative describes (and that the LABFORGE NOTE at the top of Lab 3 flagged as needed for "iteration 2"), and add an optional serverless bonus module.

## Why this exists

The current upstream `lab3/app-repo/modules/app/main.tf` deploys only two `aws_ssm_parameter` resources — but Lab 3's narrative, "Plan: 7 to add" expectation, curl verification, EC2 tag-based cleanup, and "What You'll Deploy" table all describe VPC + EC2 + Apache. The LLM-walkthrough reviewer (2026-05-15) flagged 9 blockers from this mismatch. Restoring the real infrastructure is cheaper than rewriting the whole lab to be SSM-only — t3.micro for a 4-hour class with 25 students × 2 envs is ~$2 total.

## What's in here

```
modules/
├── app/                      # Main path — 7 resources per env, $0.0104/hr per env
│   ├── main.tf               # VPC + subnet + IGW + RT + RTA + SG + EC2 (httpd)
│   ├── variables.tf          # user_id, environment, instance_count
│   └── outputs.tf            # public_ip, instance_id, vpc_id, api_url (null)
└── app-serverless/           # BONUS — Lambda + API Gateway HTTP API, $0 free tier
    ├── main.tf
    ├── variables.tf          # same interface as modules/app
    ├── outputs.tf            # public_ip (null), api_url, instance_id, vpc_id (null)
    └── lambda/index.js       # tiny Node.js handler returning env-tagged HTML
environments/
├── staging/main.tf           # backend + provider + module "app" + 4 outputs
└── prod/main.tf              # same shape, different region + state key
```

## How to deploy these to the GitHub repo

```bash
cd ~/Advanced_Terraform
rm -rf lab3/app-repo
cp -r /path/to/CourseCreationKit/courses/Terraform_Day_3/labforge_iterations/repo_additions/lab3-app-repo lab3/app-repo
git add lab3/app-repo
git commit -m "Restore EC2+Apache app-repo + add serverless bonus module"
git push
```

Per the CourseCreationKit NO-DELETION policy, archive the old `lab3/app-repo/` to a `_archive/` subfolder instead of `rm -rf` if you want to preserve the SSM-only version.

## Module interface (so the swap works cleanly)

Both `modules/app` and `modules/app-serverless` accept the **same inputs** (`user_id`, `environment`, `instance_count`) and expose the **same outputs** (`public_ip`, `api_url`, `instance_id`, `vpc_id`). The only difference: `public_ip` + `vpc_id` are non-null for EC2; `api_url` is non-null for serverless. The wrapper outputs surface all four either way, so verification commands work without conditional logic.

## Switching to serverless (the bonus Task 7 in Lab 3)

After Lab 3's main flow has run end-to-end (staging deployed → approved → prod deployed → curled successfully), students edit `environments/staging/main.tf` and `environments/prod/main.tf` to change one line each:

```diff
- source = "../../modules/app"
+ source = "../../modules/app-serverless"
```

Then commit, push, watch the pipeline re-run. The plan diff shows ~7 resources to destroy + ~8 to add (the SG, EC2, VPC, subnet, IGW, RT, RT_assoc destroy; the Lambda role, log group, function, API, integration, route, stage, permission add). After apply, curl the new `api_url` output instead of `public_ip`. Same `<h1>Sample Web App</h1>` page, served via Lambda.
