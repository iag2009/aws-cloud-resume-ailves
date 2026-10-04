# AWS cost reduction and technical review, September 2026

Account `121850521501`, site https://ailves2009.com/

## Where the money was going

Every figure below was checked against the live account through the AWS CLI,
not inferred from the code.

| Service | $/month | Cause | How it was verified |
|---|---:|---|---|
| KMS | 5.00 | 5 customer-managed CMKs × $1 | `kms list-keys` across three regions |
| DynamoDB | 3.48 | 31 RCU / 31 WCU provisioned against a 25/25 free tier | `dynamodb describe-table` |
| Route 53 | 1.50 | 3 hosted zones × $0.50, two of them empty | `route53 list-hosted-zones` |
| Secrets Manager | 1.20 | 2 secrets × $0.40 plus API calls | `secretsmanager list-secrets` |
| S3 | 0.17 | 7.3 GB of old versions (3.63 GB in each of two buckets) plus RTC replication | `s3api list-object-versions` |
| CloudFront | 0.04 | actual traffic | — |
| **Total** | **11.40** | plus tax ≈ **$13.66** | |

The DynamoDB figure reconciles to the cent:
`(31−25) WCU × $0.00065 × 730 h + (31−25) RCU × $0.00013 × 730 h = $3.42`, plus storage.
The table holds 45 items totalling 993 bytes.

Expected bill once every stage is applied: **~$0.55 before tax, ~$0.66 with tax**.
What remains is only the irreducible part — $0.50 for the `ailves2009.com`
hosted zone and pennies for S3/CloudFront. That is roughly **$156/year, −95%**.

## Terraform state facts to know before the first apply

These came out of the review and they change the order of operations.

1. **`envs/dev` lives in the `default` workspace, not `dev`.**
   State sits at key `aws-cloud-resume-ailves/dev/aws-cloud-resume-ailves.tfstate`,
   which is the default-workspace path. There are no `env:/` prefixes in the bucket.

   Meanwhile `envs/dev/Makefile` runs
   `terraform workspace select dev || terraform workspace new dev`.
   `make plan` would create an **empty** `dev` workspace and plan to build the
   whole infrastructure from scratch — a second CloudFront distribution, a
   second DynamoDB table (which would fail on the name conflict), and so on.

   **Do not use `make plan` / `make apply` until that is fixed.**
   The commands below call terraform directly and stay in `default`.

2. **`envs/infra` has no state at all.**
   There is no `aws-common.tfstate` key in the `ailves-2009-terraform-state`
   bucket. Its resources do exist in AWS (the ACM certificate `9bec6541…`, the
   `ailves-2009-logs-us-east-2` bucket, the KMS key `5ea0b95d…` in eu-central-1,
   the DNS query logging), but Terraform knows nothing about them.

   Consequence: editing `envs/infra/*.tf` deletes nothing by itself — those
   resources are removed by the Stage 0 script instead. Conversely, a
   `terraform apply` in `envs/infra` would try to **create** resources that
   already exist and fail. Until someone runs `terraform import`, stay out of
   that directory.

3. **Nothing manages the ACM certificate.** In the `envs/dev` state it appears
   only as a `data` source. It renews automatically through DNS validation
   (the CNAME is still in the zone), so this is not urgent — just worth knowing.

4. **State was written by Terraform 1.6.6; the local binary is 1.15.5.** The
   first apply upgrades the state format irreversibly. Take a copy of the
   current state file first.

## Rollout order

### Stage 0 — resources outside Terraform (−$4.30/month)

```sh
./scripts/stage0-cleanup-orphans.sh            # dry run, prints only
APPLY=1 ./scripts/stage0-cleanup-orphans.sh    # execute
```

What it does: queues 4 orphaned KMS keys for deletion, removes 2 empty hosted
zones, drops the dangling `poc-eks` NS delegation, turns off DNS query logging,
sets retention on Lambda@Edge log groups in eight regions, moves the Terraform
lock table to on-demand, removes both secrets and the stale CV copy.

Left commented out on purpose: deleting the 246 MB video (do it after the
YouTube upload) and deciding what to do with the broken CloudTrail trail.

The script is **idempotent**: a step already done — by hand or by an earlier
run — prints `SKIP` and does not stop the others. Real errors are counted, the
script still runs to the end, and it exits 1. So after looking into an error
you can simply run it again.

> KMS bills a key until it is **actually** deleted, not until it is queued.
> The window used is the shortest allowed, 7 days. To back out:
> `aws kms cancel-key-deletion`.

#### About the zones being deleted

- **`dev.ailves2009.com`** belongs to the `~/Projects/gitlab/from-slurm`
  project, not to this repository. The zone is currently empty (NS+SOA only),
  so that infrastructure appears to be torn down. It is being deleted; when
  work on from-slurm resumes, recreate the zone and re-delegate it from the
  parent `ailves2009.com`.
- **`ailvespub.info`** — the domain is **not registered**: `.info` answers
  `NXDOMAIN`, there is no delegation at the registry nameservers
  (`a0.info.afilias-nst.info`), and Route 53 Domains lists only
  `ailves2009.com`. It is a hosted zone for a domain nobody owns: no resolver
  can reach it, because the path there starts with a delegation that does not
  exist. $0.50/month for literally nothing. Safe to delete.

### Stages 1 and 2 — Terraform (−$6.30/month)

```sh
cd envs/dev
terraform workspace show          # must print: default
terraform init -upgrade -reconfigure   # provider 5.32.1 -> ~> 5.100; backend: encrypt, use_lockfile
terraform plan -var-file=inputs.dev.tfvars.json -out=tfplan
terraform show tfplan | less      # read it in full before applying
terraform apply tfplan
```

What the plan should contain:

| Action | Resource | Note |
|---|---|---|
| destroy | `module.replica_bucket.*` | the replica bucket, 3.6 GB. `force_destroy = true`, contents are deleted. **Irreversible** |
| destroy | `aws_kms_key.replica` | `fffc66df…`, 7-day window |
| destroy | `aws_s3_bucket_replication_configuration.this` | 4 rules with RTC and metrics |
| destroy | `aws_iam_role/policy/policy_attachment.replication` | |
| destroy | `aws_secretsmanager_secret*`, `random_pet.this` | if Stage 0 already ran, the resources are gone from AWS — Terraform handles that |
| destroy | `aws_cloudwatch_log_group.cfle` | the group was always empty, see below |
| create | `module.s3_bucket.aws_s3_bucket_lifecycle_configuration.this` | rotation of old versions |
| create | `aws_ssm_parameter.admin_name` | |
| replace | `aws_ssm_parameter.domain_name` | SecureString → String |
| update | `aws_dynamodb_table.this` | PROVISIONED → PAY_PER_REQUEST, `ViewsIndex` GSI removed |
| update | `aws_lambda_function.this` | python3.8 → python3.13, GET reads / POST increments, reserved concurrency 2 |
| update | `aws_lambda_function_url.this` | CORS: two origins, GET + POST, no credentials |
| forget | `aws_lambda_function.cfle`, `aws_lambda_permission.cfle` | `removed` blocks, **not destroyed** — see Stage 4 |
| create | `aws_cloudfront_response_headers_policy.security` | HSTS, CSP, nosniff, DENY framing, referrer policy |
| update | `aws_cloudfront_distribution.this` | TLS 1.2, compression on, `Managed-CachingOptimized`, 403/404 → `/404.html`, **Lambda@Edge detached** |

Checked with a read-only `terraform plan -lock=false` on 2026-10-04:
`Plan: 6 to add, 6 to change, 12 to destroy`, plus the two forgotten objects.

The CloudFront distribution takes 5–15 minutes to deploy.

**Deploy the new `website/` right after the apply — not after a merge.**
The apply attaches a Content-Security-Policy that allows only the CDNs the
*new* page uses. The old page (Bootstrap from stackpath, jQuery, Swiper,
the Font Awesome kit) breaks under it: no styles, and `index.js` throws
`$ is not defined`. This happened on 2026-10-04. Sync the site by hand
immediately after the apply (see "Deploy the site by hand" below) or apply
and merge back to back.

Post-apply checks:

```sh
curl -s https://ailves2009.com/ -o /dev/null -w '%{http_code}\n'
curl -s https://wwwzmykydj4ad2ki5axcp3luxi0altoz.lambda-url.us-east-2.on.aws/
curl -s -X POST https://wwwzmykydj4ad2ki5axcp3luxi0altoz.lambda-url.us-east-2.on.aws/   # +1
curl -sI https://ailves2009.com/ -H 'Accept-Encoding: br' | grep -iE 'content-encoding|strict-transport|content-security'
curl -s  https://ailves2009.com/no-such-page -o /dev/null -w '%{http_code}\n'   # 404, not 403
```

#### Deploy the site by hand

Same steps as `.github/workflows/main.yml`, with your own credentials:

```sh
aws s3 sync website/ s3://aws-cloud-resume-ailves-dev-source/ --delete \
  --exclude ".DS_Store" --exclude "*/.DS_Store" \
  --exclude "assets/Alexander_Ilves_Video_CV.mp4"
aws cloudfront create-invalidation --distribution-id EGALS685DA92T --paths "/*"
```

#### State locking

The backend uses S3-native locking (`use_lockfile = true`, Terraform >= 1.10)
instead of the deprecated `ailves-tf-state-lock` DynamoDB table. Check whether
other projects still lock through that table before deleting it.

### Stage 3 — CI/CD

```sh
cd envs/dev
terraform output github_actions_role_arn
```

Put that value into GitHub → Settings → Secrets and variables → Actions →
**Variables** (not Secrets) as `AWS_ROLE_ARN`. After the first successful
pipeline run, revoke the old key:

```sh
aws iam delete-access-key --user-name github-actions \
  --access-key-id AKIARYXW3M6OW75KA6N6
```

and delete the `AWS_ACCESS_KEY` / `AWS_SECRET_KEY` repository secrets.

### Stage 4 — delete the Lambda@Edge function (a few hours after Stage 1)

```sh
./scripts/stage4-remove-lambda-edge.sh            # dry run
APPLY=1 ./scripts/stage4-remove-lambda-edge.sh    # execute
```

The script refuses to run while the distribution still references the
function, and exits with code 2 while edge replicas are still draining — re-run
it later. It deletes `update_dynamodb_counter_cfle` with every version (that
closes the AWS Health python3.8 notice for us-east-1) and the
`/aws/lambda/us-east-1.update_dynamodb_counter_cfle` log groups in all regions.

Stage 4b, in code: drop `edgelambda.amazonaws.com` from the `iam_for_lambda`
trust policy and the two `removed` blocks in `envs/dev/lambda.tf`, then
plan/apply.

## What was fixed in the code

### The view counter did not work — three independent reasons

1. `func-cfle.py` only incremented when `uri == '/index.html'`, but CloudFront
   applies `default_root_object` **after** the viewer-request trigger: a visit
   to `/` reached the function as `/`, not as `/index.html`, and was not counted.
2. `func.py` never incremented anything — both mutating lines were commented
   out, and with no stored item it returned a hardcoded `views = 1`.
3. The `.counter-number` element is **commented out** in `index.html:41`, so
   `document.querySelector` returned `null` and `updateCounter()` threw a
   TypeError on every page load.

The first two are fixed. The third means uncommenting the block in the markup,
which belongs with the content rewrite.

### Everything else

- **Race in the counter.** `get_item` → `+1` → `put_item` lost views whenever
  two visitors arrived at once. Replaced with an atomic
  `UpdateItem ... ADD views :inc` — which is also one DynamoDB call instead of four.
- **A failing function took the whole site down.** An unhandled exception in a
  viewer-request Lambda@Edge returns HTTP 503 to the visitor, so a DynamoDB
  outage meant a site outage. Everything is wrapped now, the request is
  returned regardless, and the call timeouts are tight.
- **PII.** Raw visitor IP addresses were written to DynamoDB with no basis, no
  retention period and no reader. The per-IP counter is gone.
- **Python 3.8 is deprecated** — AWS blocks updates to functions on it. Both
  Lambdas moved to python3.13, which required bumping the AWS provider from
  5.32.1 (January 2024) to `~> 5.100`.
- **The Lambda@Edge log group was created under the wrong name.** Terraform
  made `/aws/lambda/update_dynamodb_counter_cfle` with 14-day retention, while
  Lambda@Edge writes to `/aws/lambda/us-east-1.<name>` in every edge region.
  The real groups (~128 MB across 8 regions) had retention set to Never expire.
  Add five `print()` calls per invocation on top. The resource is gone and
  retention is applied by the Stage 0 script.
- **The Function URL CORS config was invalid:** `allow_credentials = true`
  together with `allow_origins = ["*"]` is rejected by browsers, and
  `allow_headers` listed the forbidden headers `date` and `keep-alive`. It now
  names specific origins with `allow_credentials = false`.
- **Two `aws_secretsmanager_secret_version` resources on one `secret_id`**
  overwrote each other on every apply, making the stored value
  non-deterministic. Secrets Manager is gone entirely: neither `admin_name`
  nor `domain_name` is a secret.
- **`aws_iam_policy_attachment`** for replication is an *exclusive* resource —
  it detaches the policy from every other role and user. Removed along with
  replication; `lambda.tf` uses the correct `aws_iam_role_policy_attachment`.
- **The DynamoDB table name was hardcoded in both `.py` files.** Renaming
  `var.project` silently broke the Lambdas. The code is now generated from
  `*.py.tftpl` through `templatefile`.
- **TLS 1.1** on the distribution → `TLSv1.2_2021`.
- **The "Download CV" button served a stale résumé.** The bucket held two PDFs:
  `Aleksandr Ilves_CV_EuroPass.pdf` (with a space, February 2024) and
  `Aleksandr_Ilves_CV_EuroPass.pdf` (March 2024). The markup pointed at the first.
- **The `github-actions` IAM key was issued 2022-02-12 and never rotated.**
  Replaced with OIDC (`envs/dev/github_oidc.tf`).
- **The pipeline never invalidated CloudFront** — changes took up to a day to
  reach visitors (`max_ttl = 86400`). Invalidation and `--delete` added.
- **Typo in `.gitignore`:** `**/website/assetss/*.mp4` (three "s"). The rule
  never matched, so the 246 MB video went into the repository — `.git` is 498 MB.
- **`.gitlab-ci.yml`** was a boilerplate stub: `sleep 60` instead of tests,
  `export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID`. Replaced with fmt/validate/plan.
- **Swiper and jQuery are gone.** Swiper wrapped the page without a single
  slide; jQuery 3.4.1 (CVE-2020-11022/11023) only drove a menu toggle whose
  button did not exist. The remaining third-party styles carry SRI hashes and
  are the only origins the CSP allows.

## Open items that need your decision

- **CloudTrail has been broken since 2024-02-10.** Trail `trail-us-east-2`
  writes to bucket `aws-cloudtrail-logs-121850521501-4a34acff`, which does not
  exist (`LatestDeliveryError: NoSuchBucket`). The account has had no audit
  logs for two and a half years. Either delete the trail or recreate the
  bucket — see section 7 of the script.
- **`envs/infra` has no state.** Either `terraform import` the existing
  resources or declare the directory dead and delete it.
- **`envs/dev/Makefile` switches to a workspace that does not exist** (see above).
- **`envs/tst/**` contains committed `terraform.tfstate` files** — they are
  under `.gitignore` now, but they remain in git history. Worth scanning for
  secrets.
- **Dead code:** `envs/dev/ecr.tf` and `envs/infra/beanstalk.tf` are commented
  out in full, and `envs/dev/outputs.tf` is empty (the outputs live in
  `cloudfront.tf`). `ecr.tf` also still carries Russian comments, unlike the
  rest of the tree.
- **The account ID `121850521501` is hardcoded** in the `variables.tf` defaults.
- **`.git` is 498 MB** because of the video. Cleaning it means rewriting
  history (`git filter-repo`) and force-pushing to both remotes — a destructive
  operation, do it deliberately.
