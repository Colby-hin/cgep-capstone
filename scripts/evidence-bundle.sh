#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

TF_DIR="${TF_DIR:-${ROOT_DIR}/terraform}"
POLICY_DIR="${POLICY_DIR:-${ROOT_DIR}/policies}"
AWS_REGION="${AWS_REGION:-us-east-1}"
DEST_ROOT="${1:-/tmp/cgep-evidence}"

TIMESTAMP="$(
  date -u +%Y%m%dT%H%M%SZ
)"

BUNDLE_ID="${GITHUB_RUN_ID:-local}-${TIMESTAMP}"
EVIDENCE_NAME="cgep-evidence-${BUNDLE_ID}"
EVIDENCE_DIR="${DEST_ROOT}/${EVIDENCE_NAME}"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

for required_command in \
  aws \
  conftest \
  git \
  jq \
  opa \
  sha256sum \
  tar \
  terraform
do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "ERROR: Required command is missing: ${required_command}" >&2
    exit 1
  fi
done

mkdir -p \
  "${EVIDENCE_DIR}/aws" \
  "${EVIDENCE_DIR}/policy" \
  "${EVIDENCE_DIR}/repository" \
  "${EVIDENCE_DIR}/terraform"

PLAN_FILE="${WORK_DIR}/terraform.tfplan"
PLAN_JSON="${WORK_DIR}/terraform-plan.json"
STATE_JSON="${WORK_DIR}/terraform-state.json"

echo "===== REPOSITORY EVIDENCE ====="

git -C "$ROOT_DIR" status --short \
  > "${EVIDENCE_DIR}/repository/git-status.txt"

git -C "$ROOT_DIR" log -1 \
  --format=fuller \
  > "${EVIDENCE_DIR}/repository/git-commit.txt"

git -C "$ROOT_DIR" remote get-url origin \
  > "${EVIDENCE_DIR}/repository/git-origin.txt"

GIT_COMMIT="$(
  git -C "$ROOT_DIR" rev-parse HEAD
)"

GIT_BRANCH="$(
  git -C "$ROOT_DIR" branch --show-current
)"

GIT_ORIGIN="$(
  git -C "$ROOT_DIR" remote get-url origin
)"

echo "===== POLICY EVIDENCE ====="

opa check --strict "$POLICY_DIR" \
  > "${EVIDENCE_DIR}/policy/opa-check.txt" \
  2>&1

opa test "$POLICY_DIR" \
  > "${EVIDENCE_DIR}/policy/opa-tests.txt" \
  2>&1

echo "===== TERRAFORM EVIDENCE ====="

terraform -chdir="$TF_DIR" validate -no-color \
  > "${EVIDENCE_DIR}/terraform/validate.txt" \
  2>&1

set +e

terraform -chdir="$TF_DIR" plan \
  -input=false \
  -no-color \
  -out="$PLAN_FILE" \
  > "${EVIDENCE_DIR}/terraform/plan.txt" \
  2>&1

PLAN_EXIT=$?

set -e

case "$PLAN_EXIT" in
  0|2)
    ;;
  *)
    echo "ERROR: Terraform plan failed with exit code ${PLAN_EXIT}." >&2
    cat "${EVIDENCE_DIR}/terraform/plan.txt" >&2
    exit "$PLAN_EXIT"
    ;;
esac

printf '%s\n' "$PLAN_EXIT" \
  > "${EVIDENCE_DIR}/terraform/plan-exit-code.txt"

terraform -chdir="$TF_DIR" show \
  -json \
  "$PLAN_FILE" \
  > "$PLAN_JSON"

terraform -chdir="$TF_DIR" show \
  -json \
  > "$STATE_JSON"

jq '{
  format_version,
  terraform_version,
  resource_change_count: (.resource_changes | length),
  actions: [
    .resource_changes[]? |
    {
      address,
      actions: .change.actions
    }
  ]
}' "$PLAN_JSON" \
  > "${EVIDENCE_DIR}/terraform/plan-summary.json"

conftest test \
  "$PLAN_JSON" \
  --policy "$POLICY_DIR" \
  > "${EVIDENCE_DIR}/policy/conftest.txt" \
  2>&1

state_value() {
  local resource_address="$1"
  local attribute_name="$2"

  jq -r \
    --arg address "$resource_address" \
    --arg attribute "$attribute_name" \
    '[
       .. |
       objects |
       select(.address? == $address) |
       .values[$attribute]
     ] |
     first // empty' \
    "$STATE_JSON"
}

UPLOAD_BUCKET="$(
  state_value \
    "aws_s3_bucket.uploads" \
    "bucket"
)"

DYNAMODB_TABLE="$(
  state_value \
    "aws_dynamodb_table.intake" \
    "name"
)"

EVIDENCE_BUCKET="$(
  terraform -chdir="$TF_DIR" \
    output -raw evidence_vault_bucket
)"

KMS_KEY_ARN="$(
  terraform -chdir="$TF_DIR" \
    output -raw capstone_kms_key_arn
)"

CLOUDTRAIL_NAME="$(
  state_value \
    "aws_cloudtrail.capstone" \
    "name"
)"

CLOUDTRAIL_BUCKET="$(
  state_value \
    "aws_s3_bucket.cloudtrail_logs" \
    "bucket"
)"

LAMBDA_ROLE_NAME="$(
  state_value \
    "aws_iam_role.lambda" \
    "name"
)"

LAMBDA_POLICY_NAME="$(
  state_value \
    "aws_iam_role_policy.lambda_inline" \
    "name"
)"

declare -A REQUIRED_VALUES=(
  [UPLOAD_BUCKET]="$UPLOAD_BUCKET"
  [DYNAMODB_TABLE]="$DYNAMODB_TABLE"
  [EVIDENCE_BUCKET]="$EVIDENCE_BUCKET"
  [KMS_KEY_ARN]="$KMS_KEY_ARN"
  [CLOUDTRAIL_NAME]="$CLOUDTRAIL_NAME"
  [CLOUDTRAIL_BUCKET]="$CLOUDTRAIL_BUCKET"
  [LAMBDA_ROLE_NAME]="$LAMBDA_ROLE_NAME"
  [LAMBDA_POLICY_NAME]="$LAMBDA_POLICY_NAME"
)

for value_name in "${!REQUIRED_VALUES[@]}"; do
  if [ -z "${REQUIRED_VALUES[$value_name]}" ]; then
    echo "ERROR: Terraform value could not be resolved: ${value_name}" >&2
    exit 1
  fi
done

echo "===== LIVE AWS EVIDENCE ====="

aws sts get-caller-identity \
  > "${EVIDENCE_DIR}/aws/caller-identity.json"

aws s3api get-bucket-encryption \
  --region "$AWS_REGION" \
  --bucket "$UPLOAD_BUCKET" \
  > "${EVIDENCE_DIR}/aws/uploads-encryption.json"

aws s3api get-bucket-versioning \
  --region "$AWS_REGION" \
  --bucket "$UPLOAD_BUCKET" \
  > "${EVIDENCE_DIR}/aws/uploads-versioning.json"

aws s3api get-public-access-block \
  --region "$AWS_REGION" \
  --bucket "$UPLOAD_BUCKET" \
  > "${EVIDENCE_DIR}/aws/uploads-public-access.json"

aws s3api get-bucket-policy \
  --region "$AWS_REGION" \
  --bucket "$UPLOAD_BUCKET" \
  --query Policy \
  --output text |
  jq . \
    > "${EVIDENCE_DIR}/aws/uploads-policy.json"

aws dynamodb describe-table \
  --region "$AWS_REGION" \
  --table-name "$DYNAMODB_TABLE" \
  --query '{
    TableName:Table.TableName,
    TableStatus:Table.TableStatus,
    SSEDescription:Table.SSEDescription
  }' \
  > "${EVIDENCE_DIR}/aws/dynamodb-encryption.json"

aws kms describe-key \
  --region "$AWS_REGION" \
  --key-id "$KMS_KEY_ARN" \
  --query 'KeyMetadata' \
  > "${EVIDENCE_DIR}/aws/kms-key.json"

aws kms get-key-rotation-status \
  --region "$AWS_REGION" \
  --key-id "$KMS_KEY_ARN" \
  > "${EVIDENCE_DIR}/aws/kms-rotation.json"

aws iam get-role-policy \
  --role-name "$LAMBDA_ROLE_NAME" \
  --policy-name "$LAMBDA_POLICY_NAME" \
  > "${EVIDENCE_DIR}/aws/lambda-inline-policy.json"

aws s3api get-bucket-encryption \
  --region "$AWS_REGION" \
  --bucket "$EVIDENCE_BUCKET" \
  > "${EVIDENCE_DIR}/aws/evidence-vault-encryption.json"

aws s3api get-bucket-versioning \
  --region "$AWS_REGION" \
  --bucket "$EVIDENCE_BUCKET" \
  > "${EVIDENCE_DIR}/aws/evidence-vault-versioning.json"

aws s3api get-public-access-block \
  --region "$AWS_REGION" \
  --bucket "$EVIDENCE_BUCKET" \
  > "${EVIDENCE_DIR}/aws/evidence-vault-public-access.json"

aws s3api get-object-lock-configuration \
  --region "$AWS_REGION" \
  --bucket "$EVIDENCE_BUCKET" \
  > "${EVIDENCE_DIR}/aws/evidence-vault-object-lock.json"

aws cloudtrail get-trail \
  --region "$AWS_REGION" \
  --name "$CLOUDTRAIL_NAME" \
  > "${EVIDENCE_DIR}/aws/cloudtrail-configuration.json"

aws cloudtrail get-trail-status \
  --region "$AWS_REGION" \
  --name "$CLOUDTRAIL_NAME" \
  > "${EVIDENCE_DIR}/aws/cloudtrail-status.json"

aws s3api get-bucket-versioning \
  --region "$AWS_REGION" \
  --bucket "$CLOUDTRAIL_BUCKET" \
  > "${EVIDENCE_DIR}/aws/cloudtrail-bucket-versioning.json"

AWS_ACCOUNT_ID="$(
  jq -r '.Account' \
    "${EVIDENCE_DIR}/aws/caller-identity.json"
)"

jq -n \
  --arg bundle_id "$BUNDLE_ID" \
  --arg generated_at "$TIMESTAMP" \
  --arg repository "$GIT_ORIGIN" \
  --arg branch "$GIT_BRANCH" \
  --arg commit "$GIT_COMMIT" \
  --arg aws_account_id "$AWS_ACCOUNT_ID" \
  --arg aws_region "$AWS_REGION" \
  --arg upload_bucket "$UPLOAD_BUCKET" \
  --arg dynamodb_table "$DYNAMODB_TABLE" \
  --arg evidence_bucket "$EVIDENCE_BUCKET" \
  --arg kms_key_arn "$KMS_KEY_ARN" \
  --arg cloudtrail_name "$CLOUDTRAIL_NAME" \
  --arg cloudtrail_bucket "$CLOUDTRAIL_BUCKET" \
  --argjson terraform_plan_exit "$PLAN_EXIT" \
  '{
    evidence_bundle_id: $bundle_id,
    generated_at_utc: $generated_at,
    repository: $repository,
    branch: $branch,
    commit: $commit,
    aws: {
      account_id: $aws_account_id,
      region: $aws_region
    },
    resources: {
      upload_bucket: $upload_bucket,
      dynamodb_table: $dynamodb_table,
      evidence_bucket: $evidence_bucket,
      kms_key_arn: $kms_key_arn,
      cloudtrail_name: $cloudtrail_name,
      cloudtrail_bucket: $cloudtrail_bucket
    },
    verification: {
      opa_unit_tests: true,
      conftest_gate: true,
      terraform_plan_exit_code: $terraform_plan_exit
    }
  }' \
  > "${EVIDENCE_DIR}/metadata.json"

echo "===== MANIFEST AND ARCHIVE ====="

(
  cd "$EVIDENCE_DIR"

  find . \
    -type f \
    ! -name MANIFEST.sha256 \
    -print0 |
    sort -z |
    xargs -0 sha256sum \
      > MANIFEST.sha256
)

ARCHIVE_PATH="${DEST_ROOT}/${EVIDENCE_NAME}.tar.gz"

tar \
  -C "$DEST_ROOT" \
  -czf "$ARCHIVE_PATH" \
  "$EVIDENCE_NAME"

sha256sum "$ARCHIVE_PATH" \
  > "${ARCHIVE_PATH}.sha256"

echo
echo "PASS: Evidence bundle created."
echo "EVIDENCE_DIRECTORY=$EVIDENCE_DIR"
echo "EVIDENCE_ARCHIVE=$ARCHIVE_PATH"
echo "EVIDENCE_ARCHIVE_SHA256=${ARCHIVE_PATH}.sha256"
