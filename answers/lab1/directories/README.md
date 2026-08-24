# lab1-directories

Directory-structure pattern as the contrast to workspaces in Lab 1 Part D.

## Layout

```
lab1-directories/
├── README.md                  (this file)
├── modules/
│   └── app/
│       ├── main.tf            shared application logic + remote state read
│       ├── variables.tf       module inputs
│       └── outputs.tf         module outputs
├── dev/
│   ├── providers.tf           dev backend (key: directories/dev/...)
│   ├── main.tf                environment = "dev" (explicit, not workspace)
│   └── terraform.tfvars.example
└── staging/
    ├── providers.tf           staging backend (key: directories/staging/...)
    ├── main.tf                environment = "staging" (explicit)
    └── terraform.tfvars.example
```

## Why no workspaces here?

That's the entire teaching point. With workspaces, switching environments is one command (`terraform workspace select staging`) and the change isn't visible in source control. With directories, switching environments is `cd ../staging` — physically different, harder to do by accident, easier for code review to spot.

## Prerequisites

- The `lab1-networking/` state has already been applied so `terraform_remote_state` has something to read.
- Your S3 state bucket from Day 2 exists.

## Usage (per environment)

```bash
cd dev/    # or cd staging/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your account and state_bucket_name
# Edit providers.tf with your bucket name (backend blocks can't take variables)
terraform init
terraform apply
```

## Cleanup

```bash
cd dev/    && terraform destroy
cd ../staging/ && terraform destroy
```
