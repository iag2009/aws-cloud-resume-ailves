#!/usr/bin/env bash
#---------------------------------------------------------------------
# Stage 0: clean up orphaned resources that are not in any Terraform state.
#
# Saves ~$4.30/month (4 KMS CMKs + 2 empty Route 53 zones + 2 secrets).
# Also fixes Lambda@Edge log retention and removes the dangling poc-eks NS
# delegation (a subdomain-takeover risk).
#
# The script is idempotent: a step already done — by hand or by an earlier
# run — is reported as SKIP and does not stop the rest.
#
# DRY RUN by default; it only prints what it would do.
# To execute:  APPLY=1 ./scripts/stage0-cleanup-orphans.sh
#---------------------------------------------------------------------
set -euo pipefail

APPLY="${APPLY:-0}"
ACCOUNT_EXPECTED="121850521501"
ZONE_MAIN="Z0755312283BG8LDLOJK9"   # ailves2009.com
ZONE_DEV="Z055915317726HOVKNOHE"    # dev.ailves2009.com  (empty)
ZONE_PUB="Z07277161FDM3QGFJOLH5"    # ailvespub.info      (empty)

FAILURES=0

# Signs that a resource is already in the desired state. These are not
# errors: the script has to survive a re-run and any manual work done first.
ALREADY_DONE_RE='pending deletion|NoSuchHostedZone|HostedZoneNotFound|NoSuchEntity|ResourceNotFoundException|NoSuchQueryLoggingConfig|NoSuchLogGroup|InvalidChangeBatch|but it was not found|does not exist|not found|already .*PAY_PER_REQUEST|Table is already'

run() {
  if [[ "$APPLY" != "1" ]]; then
    echo "[dry-run] $*"
    return 0
  fi

  echo "+ $*" >&2
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?

  if (( rc == 0 )); then
    [[ -n "$out" ]] && echo "$out"
    return 0
  fi

  if grep -qiE "$ALREADY_DONE_RE" <<<"$out"; then
    echo "  SKIP: already done"
    return 0
  fi

  echo "  ERROR: $out" >&2
  FAILURES=$((FAILURES + 1))
  return 0
}

# --- 0. Make sure we are in the right account ------------------------
acct="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$acct" != "$ACCOUNT_EXPECTED" ]]; then
  echo "ERROR: current account is $acct, expected $ACCOUNT_EXPECTED" >&2
  exit 1
fi
echo "Account: $acct   APPLY=$APPLY"
echo

#---------------------------------------------------------------------
# 1. KMS: 4 orphaned customer-managed keys  ->  -$4.00/month
#---------------------------------------------------------------------
# KMS bills $1/key/month until the key is ACTUALLY deleted, not until it is
# queued for deletion. The waiting window is the shortest allowed: 7 days.
# To back out at any point: aws kms cancel-key-deletion --key-id ...
echo "== 1. KMS =="

# us-east-1 / "S3 bucket replication KMS key" — untagged, not in any state.
run aws kms schedule-key-deletion --region us-east-1 \
      --key-id 0caa7e48-dfb6-401f-8f1e-fc7057dd5edb --pending-window-in-days 7

# us-east-2 / "dataservices=clgroup-us-east-2" — already Disabled, belongs to
# an unrelated project.
run aws kms schedule-key-deletion --region us-east-2 \
      --key-id 267534fc-6284-4c91-a280-51f207b6379e --pending-window-in-days 7

# us-east-2 / the CloudTrail key. Verified: trail-us-east-2 writes to a bucket
# that does not exist (LatestDeliveryError=NoSuchBucket since 2024-02-10), so
# no object is encrypted with this key.
run aws kms schedule-key-deletion --region us-east-2 \
      --key-id dc776ae2-5f00-4261-b255-65f8cb189b31 --pending-window-in-days 7

# eu-central-1 / the replication key from envs/infra. Terraform does NOT manage
# it: there is no aws-common.tfstate in the ailves-2009-terraform-state bucket,
# so envs/infra is entirely outside state. Nothing references this key.
#
# Do NOT touch the other eu-central-1 key (fffc66df-...): it is in the envs/dev
# state and terraform apply removes it in Stage 1.
run aws kms schedule-key-deletion --region eu-central-1 \
      --key-id 5ea0b95d-7b68-4e29-8fa9-ed627319df49 --pending-window-in-days 7
echo

#---------------------------------------------------------------------
# 2. Route 53: 2 empty zones  ->  -$1.00/month
#---------------------------------------------------------------------
# Both hold only NS+SOA, which are deleted together with the zone.
#
# dev.ailves2009.com belongs to the from-slurm project, whose infrastructure
# appears to be torn down. Recreate and re-delegate the zone when that work
# resumes.
#
# ailvespub.info is a zone for a domain nobody owns: .info answers NXDOMAIN,
# there is no delegation at the registry nameservers, and Route 53 Domains
# lists only ailves2009.com. No resolver can ever reach it.
echo "== 2. Route 53: empty zones =="
run aws route53 delete-hosted-zone --id "$ZONE_DEV"
run aws route53 delete-hosted-zone --id "$ZONE_PUB"
echo

#---------------------------------------------------------------------
# 3. Route 53: dangling poc-eks records in the main zone
#---------------------------------------------------------------------
# The NS record delegates to a zone that no longer exists -> subdomain
# takeover. The CNAME validated an ACM certificate that is also gone.
echo "== 3. Route 53: dangling poc-eks records =="
batch=$(mktemp)
cat > "$batch" <<'JSON'
{
  "Comment": "stage0: remove dangling poc-eks delegation and stale ACM validation record",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "poc-eks.ailves2009.com.",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "ns-128.awsdns-16.com."},
          {"Value": "ns-1799.awsdns-32.co.uk."},
          {"Value": "ns-1261.awsdns-29.org."},
          {"Value": "ns-963.awsdns-56.net."}
        ]
      }
    },
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "_9d80d106f089b4e78fd58355d20766d5.poc-eks.ailves2009.com.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "_2fb44e9ba6fb1a53fd4126bbd202535b.jkddzztszm.acm-validations.aws."}
        ]
      }
    }
  ]
}
JSON
run aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_MAIN" \
      --change-batch "file://$batch"
[[ "$APPLY" == "1" ]] || echo "  (change batch written to $batch)"
echo

#---------------------------------------------------------------------
# 3b. Route 53: DNS query logging
#---------------------------------------------------------------------
# Configured in envs/infra/route53.tf but, like the KMS key above, outside
# Terraform state — so it is removed here rather than by an apply.
# Nobody read the DNS query logs of a personal site, and CloudWatch ingestion
# costs $0.50/GB (3.7 MB accumulated).
#
# This also clears three configurations pointing at zones that no longer
# exist: ailves.com (x2) and master.ailves.com.
echo "== 3b. Route 53: query logging =="
# Process substitution rather than a pipe: in a pipe the loop would run in a
# subshell and the FAILURES counter would not survive.
while read -r cfg; do
  [[ -n "$cfg" ]] || continue
  run aws route53 delete-query-logging-config --id "$cfg"
done < <(aws route53 list-query-logging-configs \
           --query 'QueryLoggingConfigs[].Id' --output text 2>/dev/null | tr '\t' '\n')
run aws logs delete-log-group --region us-east-1 --log-group-name "/aws/route53/ailves2009.com"
echo

#---------------------------------------------------------------------
# 4. CloudWatch: retention for Lambda@Edge logs
#---------------------------------------------------------------------
# Lambda@Edge writes to /aws/lambda/us-east-1.<name> in EVERY edge region, not
# to the group Terraform creates. Those groups currently hold ~128 MB with
# retention set to Never expire. Set 7 days wherever the group exists.
echo "== 4. CloudWatch: Lambda@Edge log retention =="
EDGE_LOG_GROUP="/aws/lambda/us-east-1.update_dynamodb_counter_cfle"
for region in $(aws ec2 describe-regions --region us-east-1 --query 'Regions[].RegionName' --output text); do
  if aws logs describe-log-groups --region "$region" \
       --log-group-name-prefix "$EDGE_LOG_GROUP" \
       --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$EDGE_LOG_GROUP"; then
    run aws logs put-retention-policy --region "$region" \
          --log-group-name "$EDGE_LOG_GROUP" --retention-in-days 7
  fi
done
echo

#---------------------------------------------------------------------
# 5. DynamoDB: the Terraform lock table -> on-demand
#---------------------------------------------------------------------
# 1 RCU + 1 WCU provisioned. Pennies on its own, but it eats part of the
# 25/25 free tier that should go to the counter table.
echo "== 5. DynamoDB: ailves-tf-state-lock -> PAY_PER_REQUEST =="
run aws dynamodb update-table --region us-east-2 \
      --table-name ailves-tf-state-lock --billing-mode PAY_PER_REQUEST
echo

#---------------------------------------------------------------------
# 6. S3: the stale copy of the CV
#---------------------------------------------------------------------
# The bucket holds TWO CV files: the old one with a space in its name (443 KB,
# Feb 2024) and the current one with an underscore (473 KB, Mar 2024). The
# "Download CV" button pointed at the old one. The link fix is in Stage 3.
echo "== 6. S3: remove the stale CV copy =="
BUCKET="aws-cloud-resume-ailves-dev-source"
STALE_KEY="assets/Aleksandr Ilves_CV_EuroPass.pdf"
while read -r vid; do
  [[ -n "$vid" && "$vid" != "None" ]] || continue
  run aws s3api delete-object --bucket "$BUCKET" --key "$STALE_KEY" --version-id "$vid"
done < <(aws s3api list-object-versions --bucket "$BUCKET" --prefix "$STALE_KEY" \
           --query '[Versions[].VersionId, DeleteMarkers[].VersionId][]' \
           --output text 2>/dev/null | tr '\t' '\n')
echo

#---------------------------------------------------------------------
# 6a. S3: the 246 MB video CV
#---------------------------------------------------------------------
# 246 MB is 96% of the bucket. Storage is pennies, but every view through
# CloudFront transfers 246 MB: a hundred views is about $2, more than the rest
# of the infrastructure put together.
#
# RUN THIS ONLY AFTER the video is on YouTube and the link in
# website/index.html has been updated, otherwise "Open Video CV" returns 403.
# Uncomment when ready:
#
# aws s3api list-object-versions --bucket aws-cloud-resume-ailves-dev-source \
#   --prefix "assets/Alexander_Ilves_Video_CV.mp4" \
#   --query '[Versions[].VersionId, DeleteMarkers[].VersionId][]' --output text \
#   | tr '\t' '\n' | grep -v '^$' | grep -v '^None$' | while read -r vid; do
#       aws s3api delete-object --bucket aws-cloud-resume-ailves-dev-source \
#         --key "assets/Alexander_Ilves_Video_CV.mp4" --version-id "$vid"
#     done
echo "== 6a. S3: 246 MB video — see the comment in this script =="
echo

#---------------------------------------------------------------------
# 6b. Secrets Manager  ->  -$0.80/month
#---------------------------------------------------------------------
# There are two secrets and neither holds a secret:
#   test             — not in any Terraform state, last accessed 2025-02-06
#   eel-site-secrets — managed by envs/dev, but a plain terraform destroy puts
#                      the secret into a 30-day recovery window and keeps
#                      charging $0.40/month for the whole of it
# So both are removed here and immediately, with no recovery window. Their
# values ("admin" and "ailves2009.com") move to SSM Parameter Store — Stage 1.
echo "== 6b. Secrets Manager =="
for secret in test eel-site-secrets; do
  run aws secretsmanager delete-secret --region us-east-2 \
        --secret-id "$secret" --force-delete-without-recovery
done
echo

#---------------------------------------------------------------------
# 7. CloudTrail: the broken trail
#---------------------------------------------------------------------
# trail-us-east-2 writes to bucket aws-cloudtrail-logs-121850521501-4a34acff,
# which does not exist. Last successful delivery: 2024-02-10. The account has
# had no audit logs for two and a half years.
# Two options — uncomment whichever you want:
#   a) delete the trail (it writes nothing anyway):
# run aws cloudtrail delete-trail --region us-east-2 --name trail-us-east-2
#   b) recreate the bucket and fix logging — this adds an S3 storage cost.
#      For a personal account the free 90-day CloudTrail Event history is
#      usually enough.
echo "== 7. CloudTrail: trail is broken, your call — see the comment in this script =="
echo

rm -f "$batch"

if [[ "$APPLY" != "1" ]]; then
  echo "That was a DRY RUN. To execute: APPLY=1 $0"
  exit 0
fi

if (( FAILURES > 0 )); then
  echo "Finished with $FAILURES error(s). Look into them and re-run —" >&2
  echo "steps already completed will be reported as SKIP." >&2
  exit 1
fi

echo "Done, no errors."
echo
echo "What to check:"
echo "  * KMS keys enter PendingDeletion for 7 days; billing stops only once"
echo "    they are actually deleted."
echo "  * Savings show up in Billing -> Cost Explorer in 2-3 days."
echo "  * The fifth key (fffc66df, eu-central-1) is removed by the Stage 1"
echo "    terraform apply."
