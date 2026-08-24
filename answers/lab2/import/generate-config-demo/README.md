# Generate-Config Demo

This directory exists only to show what `terraform plan -generate-config-out`
actually produces when import blocks reference resources without matching
configuration.

The parent directory (`lab2/import/`) ships pre-cleaned `network.tf` and
`security-group.tf` for the real import flow. If you tried to run
generate-config there, terraform would see every resource already has config
and exit 0 silently — the lesson disappears.

This subfolder strips out the cleaned configs so generate-config has work to
do (and fails the way Module 2 describes it would).

## Run the demo

```bash
cd ~/Advanced_Terraform/lab2/import/generate-config-demo
cp ../terraform.tfvars terraform.tfvars      # reuse the IDs you already pasted
terraform init                                 # local state, no backend
terraform plan -generate-config-out=generated.tf
# expected: "Conflicting configuration arguments" errors on availability_zone, tags_all, etc.

cat generated.tf | head -40                    # inspect the messy partial output
rm generated.tf                                # clean up
cd ..                                           # back to lab2/import/ for the real import
```
