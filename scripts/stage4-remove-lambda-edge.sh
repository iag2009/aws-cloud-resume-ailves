#!/usr/bin/env bash
#---------------------------------------------------------------------
# Stage 4: delete the former Lambda@Edge view counter.
#
# Run this AFTER the terraform apply that detached the function from
# CloudFront (envs/dev/cloudfront.tf) and dropped it from state (the `removed`
# blocks in envs/dev/lambda.tf), and after the distribution reached Deployed.
#
# Lambda refuses to delete a function while its edge replicas still exist.
# They drain within a few hours of the detach; until then step 2 fails with
# "replicated function" — just re-run the script later.
#
# Deleting the function removes $LATEST and every published version, so this
# also closes the AWS Health notice about python3.8 for us-east-1.
#
# DRY RUN by default; it only prints what it would do.
# To execute:  APPLY=1 ./scripts/stage4-remove-lambda-edge.sh
#---------------------------------------------------------------------
set -euo pipefail

APPLY="${APPLY:-0}"
ACCOUNT_EXPECTED="121850521501"
DISTRIBUTION_ID="EGALS685DA92T"
FUNCTION="update_dynamodb_counter_cfle"

run() {
  if [[ "$APPLY" != "1" ]]; then
    echo "[dry-run] $*"
    return 0
  fi
  echo "+ $*" >&2
  "$@"
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
# 1. The distribution must no longer reference the function
#---------------------------------------------------------------------
echo "== 1. CloudFront $DISTRIBUTION_ID =="
status="$(aws cloudfront get-distribution --id "$DISTRIBUTION_ID" \
  --query 'Distribution.Status' --output text)"
assoc="$(aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" \
  --query 'DistributionConfig.DefaultCacheBehavior.LambdaFunctionAssociations.Quantity' --output text)"
echo "  status=$status  lambda associations=$assoc"
if [[ "$assoc" != "0" || "$status" != "Deployed" ]]; then
  echo "ERROR: run terraform apply in envs/dev first and wait for status Deployed." >&2
  exit 1
fi
echo

#---------------------------------------------------------------------
# 2. The function, with all of its versions
#---------------------------------------------------------------------
echo "== 2. Lambda function $FUNCTION (us-east-1) =="
if ! aws lambda get-function --region us-east-1 --function-name "$FUNCTION" >/dev/null 2>&1; then
  echo "  SKIP: already deleted"
elif [[ "$APPLY" != "1" ]]; then
  run aws lambda delete-function --region us-east-1 --function-name "$FUNCTION"
else
  if ! out="$(aws lambda delete-function --region us-east-1 --function-name "$FUNCTION" 2>&1)"; then
    if grep -qi 'replicated function' <<<"$out"; then
      echo "  NOT YET: edge replicas are still being removed. Re-run in an hour or two." >&2
      exit 2
    fi
    echo "  ERROR: $out" >&2
    exit 1
  fi
  echo "  deleted"
fi
echo

#---------------------------------------------------------------------
# 3. Log groups the replicas wrote in every edge region
#---------------------------------------------------------------------
# Lambda@Edge logs to /aws/lambda/us-east-1.<name> in the region of the edge
# location that served the request. Without the function they are dead weight.
echo "== 3. Lambda@Edge log groups =="
for region in $(aws ec2 describe-regions --region us-east-1 --query 'Regions[].RegionName' --output text); do
  for group in $(aws logs describe-log-groups --region "$region" \
      --log-group-name-prefix "/aws/lambda/us-east-1.$FUNCTION" \
      --query 'logGroups[].logGroupName' --output text); do
    run aws logs delete-log-group --region "$region" --log-group-name "$group"
  done
done
echo

if [[ "$APPLY" != "1" ]]; then
  echo "That was a DRY RUN. To execute: APPLY=1 $0"
  exit 0
fi

echo "Done."
echo
echo "Last step, in code (stage 4b): in envs/dev/lambda.tf remove"
echo "\"edgelambda.amazonaws.com\" from the iam_for_lambda trust policy and the"
echo "two \`removed\` blocks, then terraform plan/apply."
