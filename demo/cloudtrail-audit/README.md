# CloudTrail Audit Demo (instructor-run)

> 📖 **Students do not run this.** The instructor applies it once per cohort, before the class starts. Lab 4's student instructions are in [`../../labs/lab4.md`](../../labs/lab4.md).

One CloudTrail trail for the whole class. It records **management events** plus **S3 data events on every bucket in the account**, and delivers both to an S3 bucket (raw log files) and to a CloudWatch log group (what students query in Lab 4).

Object-level calls such as `PutObject` never appear in CloudTrail Event history. Without a trail there is no way to see the writes Terraform makes to a state file, which is exactly what Lab 4 Task 2 asks students to find.

## Why one shared trail

CloudTrail allows a maximum of 5 trails per Region and that quota cannot be increased. A per-student trail would fail on the sixth apply. Students share the log group read-only and filter to their own bucket or user ID, so nobody's query interferes with anyone else's.

## What it creates

Eight resources. Names below use the default `class_prefix` of `advanced-terraform`.

| Resource | Name |
|---|---|
| `aws_cloudtrail.class` | `advanced-terraform-audit-trail` |
| `aws_s3_bucket.trail` | `advanced-terraform-audit-trail-<suffix>` — 6-character lowercase suffix from `random_string.suffix` |
| `aws_s3_bucket_public_access_block.trail` | all four blocks on |
| `aws_s3_bucket_policy.trail` | `AWSCloudTrailAclCheck` (`s3:GetBucketAcl`) + `AWSCloudTrailWrite` (`s3:PutObject` under `AWSLogs/<account-id>/*`) |
| `aws_cloudwatch_log_group.trail` | `/aws/cloudtrail/advanced-terraform` |
| `aws_iam_role.trail_to_logs` | `advanced-terraform-cloudtrail-to-logs` |
| `aws_iam_role_policy.trail_to_logs` | `write-to-log-group` |
| `random_string.suffix` | 6 characters, lowercase, no specials |

**Both delivery targets are configured on the same trail.** `s3_bucket_name` sends the raw log files to the bucket; `cloud_watch_logs_group_arn` and `cloud_watch_logs_role_arn` send the same events to the log group.

### Permissions the trail needs

- **To the bucket** — the bucket policy grants `cloudtrail.amazonaws.com` both `s3:GetBucketAcl` on the bucket and `s3:PutObject` under `AWSLogs/<account-id>/*`, with the `s3:x-amz-acl = bucket-owner-full-control` condition. Both statements are required or `CreateTrail` fails validation. The trail carries `depends_on = [aws_s3_bucket_policy.trail]` for that reason.
- **To the log group** — `aws_iam_role.trail_to_logs` is assumable by `cloudtrail.amazonaws.com` and carries `logs:CreateLogStream` and `logs:PutLogEvents` on the log group ARN.

### Event selectors

Two advanced event selectors:

1. **S3 object events on every bucket** — `eventCategory = Data`, `resources.type = AWS::S3::Object`, and no bucket named. Selecting all buckets means a student's Lab 1 state bucket is covered without this config knowing its name, and it sidesteps the 250 data-resource limit that applies when buckets are listed individually.
2. **All management events** — `eventCategory = Management`.

> **Why the trail's own bucket is excluded.** Selector 1 also carries `resources.ARN not_starts_with [<trail bucket ARN>]`. Every file CloudTrail writes to its bucket is a `PutObject` on an S3 bucket, which matches the selector, which produces another event, which produces another file. Without the exclusion the trail records its own deliveries: it bills per event and buries real activity in student queries.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `class_prefix` | `advanced-terraform` | Names the trail, its bucket, and the log group. See the warning under **How Lab 4 uses it** before changing this. |
| `primary_region` | `us-east-2` | Region the trail runs in. Use the region the class deploys to, so S3 data events are recorded locally. |
| `multi_region` | `true` | Lab 3 deploys prod to `us-west-2`, so `true` gives the full audit picture. |
| `log_retention_days` | `7` | CloudWatch Logs retention, which caps the storage bill. |

## Deploy

> **Not from the deploy VM.** Terraform running on the classroom VM authenticates as
> `Terraform-InstanceRole`, and the policy that role carries (`TerraformPowerUser`) has **no
> CloudTrail permissions at all** — `terraform apply` fails with `AccessDenied` on `CreateTrail`.
> That is deliberate: the role is shared with every student, and `cloudtrail:*` would let anyone
> in the class call `StopLogging` or `DeleteTrail`. Run it somewhere your own administrator
> identity applies instead.

Run it as **yourself**, from CloudShell. It launches from the console toolbar, already
authenticated as your own IAM user, so there are no credentials to configure and no profile to
pick. Open it **in the region the class deploys to** — CloudShell's home directory is per-region.

**1 — install Terraform, if it is not already there.**

CloudShell does not ship Terraform. Its 1 GB `$HOME` does persist between sessions, so this is
once per account per region, not once per demo. The block below is safe to re-run: it installs
only when `terraform` is missing and never duplicates the PATH line.

```bash
mkdir -p ~/bin
grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/bin:$PATH

if command -v terraform >/dev/null; then
    echo "already installed: $(terraform version | head -1)"
else
    curl -sS -o /tmp/tf.zip https://releases.hashicorp.com/terraform/1.15.9/terraform_1.15.9_linux_amd64.zip
    unzip -q -o /tmp/tf.zip -d ~/bin
    terraform version
fi
```

**Expected:** a version line either way — `Terraform v1.15.9` on a first run, or
`already installed: Terraform v1.15.9` afterwards.

**2 — get the demo.** Also safe to re-run; it pulls if the clone already exists.

```bash
cd ~
if [ -d Advanced_Terraform ]; then
    git -C Advanced_Terraform pull --ff-only
else
    git clone https://github.com/AWSClassroom-com/Advanced_Terraform.git
fi
cd ~/Advanced_Terraform/demo/cloudtrail-audit
```

**3 — apply it.**

State is **local on purpose**. You apply this once per cohort, so there is no shared state to
coordinate and no chicken-and-egg with Lab 1's state bucket. There is no backend block and no
`-backend-config` to pass.

```bash
terraform init
terraform apply
```

> **Keep this directory.** `terraform.tfstate` here is the only way to tear the demo down later,
> and it lives in CloudShell's `$HOME`, which survives between sessions. Destroy from this same
> region's CloudShell.

> **If you would rather use your own workstation**, everything above applies except step 1 — clone
> the repo, `cd` to `demo/cloudtrail-audit`, and set `AWS_PROFILE` to a profile with administrator
> access in the classroom account before `terraform init`.

Keep the directory and its `terraform.tfstate` file. That local state is the only way to tear the demo down later.

**Expected outputs:**

```
log_group_name = "/aws/cloudtrail/advanced-terraform"
trail_bucket   = "advanced-terraform-audit-trail-a1b2c3"
trail_name     = "advanced-terraform-audit-trail"
```

## Verify it is delivering

Run these before class, and again if a student reports an empty query.

1. **Confirm the trail is logging**

    ```bash
    aws cloudtrail get-trail-status --region us-east-2 \
        --name advanced-terraform-audit-trail
    ```
    Look for `"IsLogging": true`, a `LatestDeliveryTime`, and a `LatestCloudWatchLogsDeliveryTime`. The CloudWatch field is the one Lab 4 depends on. If `LatestCloudWatchLogsDeliveryError` is populated, the role or its policy is the thing to check.

2. **Confirm the log group is receiving events**

    ```bash
    aws logs describe-log-streams --region us-east-2 \
        --log-group-name /aws/cloudtrail/advanced-terraform
    ```
    Streams are named after the account and Region. An empty list means nothing has been delivered yet.

3. **Confirm data events are being captured**

    Generate one by writing to any bucket in the account, then run the Lab 4 Task 2 query. Notice that `PutObject` rows carry `requestParameters.bucketName` and `requestParameters.key`. If management events appear but `PutObject` never does, selector 1 is the thing to check.

## How Lab 4 uses it

Lab 4 Task 2 opens **CloudWatch → Logs → Log Analytics** and runs queries whose `SOURCE` line names the log group:

```
SOURCE logGroups(namePrefix: ["/aws/cloudtrail/advanced-terraform"]) START=-12h END=0s |
```

> **The log group name is hardcoded in `labs/lab4.md`.** It appears five times: the console query, three CLI commands, and the troubleshooting section. Changing `class_prefix` renames the log group, and every one of those must be updated in the same commit.

The trail must be applied **before** students start Lab 1. Anything that happened before the trail existed was never captured, so a trail created the morning of Lab 4 gives students an empty result set.

> **The dashboard does not read this log group.** Lab 4 Task 3 deploys `lab4/observability/`, whose widgets read `AWS/CodeBuild` and `AWS/S3` CloudWatch metrics. The audit path and the metrics path are independent: the dashboard works whether or not this demo is deployed, and this demo works whether or not the dashboard is.

Locking anywhere in this repo is Terraform 1.10+ S3 native locking (`use_lockfile = true`), so the `.tflock` objects students see in their query results are S3 objects next to the state file. There is no DynamoDB table to audit.

## Tear down

```bash
cd demo/cloudtrail-audit
terraform destroy
```

The bucket carries `force_destroy = true`, so the accumulated log files are deleted with it. The log group and its events go with it as well. Saved query definitions are created by students outside this config and are not removed by `destroy`. Run this after the last cohort session, not between labs.
