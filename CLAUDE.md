# CLAUDE.md — Advanced_Terraform (Day 3 course repo)

Instructor-maintained lab repo: 4 labs, each a set of Terraform config dirs (`lab1/`–`lab4/`)
plus a student instruction doc (`labs/labN.md`). Students clone this repo and follow the docs
verbatim in a shared AWS classroom account.

## The two rules that matter most

1. **Code and lab docs move together.** Any change to lab code — resource names, variable
   names/validators, regions, backend keys, pipeline stage names, file layout — must be
   reflected in the matching `labs/labN.md` (and the nearest `README.md`) in the same commit,
   and vice versa. Most bugs found in this repo were drift: docs describing code that had
   moved on (a DynamoDB lock table that no longer exists, a lifecycle block shape that
   differed between two files, stage names the console doesn't use). Before editing a doc
   claim, verify it against the code; before changing code, grep the docs for every mention.

2. **All lab-text edits in the lab voice.** The docs read as one author. That register is:
   - Steps: `N. **Imperative title**` at column 0, second person, short declarative sentences.
   - Callouts: `> **Question or short label.**` — e.g. `> **Why a different state key from
     Lab 1?**`, `> **Cost note.**` Question-titled callouts are the house style for "why".
   - `**Expected:**` followed by a fenced block for command output; "Notice ..." to direct
     attention; bold for key terms; occasional CAPS for emphasis ("the directory IS the
     environment"); at most one em-dash aside per sentence.
   - Never: aphorisms, reader-nudging ("Impatient?"), stacked rhetorical turns, meta-commentary.
     If a sentence sounds clever, rewrite it plain.

## Placeholders and identity

- The placeholder is `userXX` (lowercase `userxx` where a file already uses it). The example
  ID is `user07`. **Never `studentXX`** — classroom IAM users are `user01`–`user50` and every
  identity variable is validated against `^user[0-9]{2}$`, so `studentXX` was never a legal
  value. The *variable name* `student_id` stays — renaming it has knock-on effects.
- Labs 1, 3, and 4 key resource names off the same ID (`user07-terraform-pipeline`,
  `user07-terraform-validate`, ...). Lab 4's dashboard widgets silently show "No data" if the
  IDs diverge — that is why the validators are strict.

## Markdown step lists (GitHub rendering)

- Main steps sit at **column 0**. A numbered line indented 4 spaces lands inside the previous
  step's content and starts a *nested* `<ol>` — GitHub styles it lower-roman (`iv.`) and every
  later step in the section renders one lower than written.
- Intentional sub-lists are indented and **restart at 1** (lab3's 8-stage flow, console
  click-throughs). Leave those alone.
- Prose references ("Step 23") do not renumber themselves — after inserting or renumbering
  steps, grep the file for `Step [0-9]` and re-check each.
- To verify rendering, POST the file to GitHub's own renderer:
  `curl -X POST https://api.github.com/markdown -d '{"text":"...","mode":"gfm"}'`.

## Terraform hygiene

- `terraform fmt -check -recursive` must pass repo-wide — lab3's pipeline Validate stage runs
  exactly that against the student's copy, so a formatting violation breaks every student's
  first push.
- `terraform validate` (after `init -backend=false`) must pass in every config dir **except**
  `lab3/app-repo/environments/{staging,prod}`, which fail by design until students replace
  the `userXX` placeholders — the failure names the file and line.
- `_archive/` directories are frozen history. Never edit them.
- Files are CRLF on disk. Scripted edits should read/write with `newline=''` and match line
  endings; set `PYTHONIOENCODING=utf-8` when printing file content on this machine.

## Facts worth not re-deriving

- Regions: `us-east-2` everywhere, except lab3 prod (`us-west-2`) — the multi-region
  promotion is intentional. Backend `region` = the *bucket's* region, independent of deploy
  region; the docs teach this distinction deliberately.
- State layout: one bucket (created by `lab1/state-infra`, name has a random suffix), one key
  per lab (`lab1-app/`, `networking/`, `directories/*`, `imported/`, `pipeline/*`,
  `observability/`). No lab reads another lab's state except Lab 1 Part D (gated by `count`
  on `state_bucket_name`).
- Locking is Terraform 1.10+ S3 native (`use_lockfile = true`) — there is no DynamoDB table
  anywhere; a lock appears as a transient `.tflock` object next to the state file.
- The pipeline triggers via `PollForSourceChanges = "true"` — API/Terraform-created pipelines
  get no EventBridge rule (only console-created ones do), so without it pushes never trigger.
- Pipeline stage names in docs must match the console exactly: `Plan-Production`, not
  `Plan-Prod`.
- Lab 2's `generate-config-demo` plan **fails with ~6 errors by design** and still writes
  `generated.tf`; the errors are the lesson. Don't "fix" it.
- Lab 2 imports the Day 1-2-shaped stack (`192.168.0.0/20`, separate `sgr-` rule resources).
  `lab1/networking` (`10.20.0.0/16`, inline SG rules) can never serve as its import source.
- `README.md` files inside lab dirs are student-facing docs too — they drift just like
  `labs/*.md` and are covered by rule 1.
