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
