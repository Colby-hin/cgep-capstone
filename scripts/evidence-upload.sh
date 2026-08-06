#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  evidence-upload.sh BUCKET KMS_KEY_ARN S3_PREFIX ARTIFACT [ARTIFACT...]

Environment:
  AWS_REGION      AWS Region. Default: us-east-1
  RECEIPT_PATH    Local receipt path. Default: /tmp/cgep-evidence-upload-receipt.json
  VALIDATE_ONLY   Set to 1 to validate inputs without uploading.
USAGE
}

if [ "$#" -lt 4 ]; then
  usage >&2
  exit 2
fi

BUCKET="$1"
KMS_KEY_ARN="$2"
S3_PREFIX="${3#/}"
shift 3

AWS_REGION="${AWS_REGION:-us-east-1}"
RECEIPT_PATH="${RECEIPT_PATH:-/tmp/cgep-evidence-upload-receipt.json}"
VALIDATE_ONLY="${VALIDATE_ONLY:-0}"

S3_PREFIX="${S3_PREFIX%/}"

for command_name in aws jq sha256sum; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: Required command is missing: ${command_name}" >&2
    exit 1
  fi
done

if [ -z "$BUCKET" ] || [ -z "$KMS_KEY_ARN" ] || [ -z "$S3_PREFIX" ]; then
  echo "ERROR: Bucket, KMS key ARN, and S3 prefix must not be empty." >&2
  exit 1
fi

declare -A SEEN_BASENAMES=()

for artifact in "$@"; do
  if [ ! -f "$artifact" ]; then
    echo "ERROR: Artifact does not exist: ${artifact}" >&2
    exit 1
  fi

  basename_value="$(basename "$artifact")"

  if [ -n "${SEEN_BASENAMES[$basename_value]:-}" ]; then
    echo "ERROR: Duplicate artifact basename: ${basename_value}" >&2
    exit 1
  fi

  SEEN_BASENAMES["$basename_value"]="true"
done

echo "===== EVIDENCE UPLOAD PLAN ====="
echo "Bucket: ${BUCKET}"
echo "KMS key: ${KMS_KEY_ARN}"
echo "Prefix: ${S3_PREFIX}"
echo "Region: ${AWS_REGION}"

for artifact in "$@"; do
  artifact_name="$(basename "$artifact")"
  artifact_hash="$(sha256sum "$artifact" | awk '{print $1}')"

  echo
  echo "Artifact: ${artifact}"
  echo "S3 key: ${S3_PREFIX}/${artifact_name}"
  echo "SHA-256: ${artifact_hash}"
done

if [ "$VALIDATE_ONLY" = "1" ]; then
  echo
  echo "PASS: Evidence-upload inputs are valid; no objects were uploaded."
  exit 0
fi

WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

ITEM_DIRECTORY="${WORK_DIR}/items"
mkdir -p "$ITEM_DIRECTORY"

item_number=0

for artifact in "$@"; do
  item_number=$((item_number + 1))

  artifact_name="$(basename "$artifact")"
  artifact_key="${S3_PREFIX}/${artifact_name}"
  artifact_hash="$(sha256sum "$artifact" | awk '{print $1}')"

  echo
  echo "===== UPLOAD: ${artifact_name} ====="

  put_response="${WORK_DIR}/put-${item_number}.json"
  head_response="${WORK_DIR}/head-${item_number}.json"
  retention_response="${WORK_DIR}/retention-${item_number}.json"

  aws s3api put-object \
    --region "$AWS_REGION" \
    --bucket "$BUCKET" \
    --key "$artifact_key" \
    --body "$artifact" \
    --server-side-encryption aws:kms \
    --ssekms-key-id "$KMS_KEY_ARN" \
    > "$put_response"

  version_id="$(
    jq -r '.VersionId // empty' "$put_response"
  )"

  if [ -z "$version_id" ] || [ "$version_id" = "null" ]; then
    echo "ERROR: S3 did not return a VersionId for ${artifact_key}." >&2
    exit 1
  fi

  aws s3api head-object \
    --region "$AWS_REGION" \
    --bucket "$BUCKET" \
    --key "$artifact_key" \
    --version-id "$version_id" \
    > "$head_response"

  aws s3api get-object-retention \
    --region "$AWS_REGION" \
    --bucket "$BUCKET" \
    --key "$artifact_key" \
    --version-id "$version_id" \
    > "$retention_response"

  jq -e \
    --arg kms_key "$KMS_KEY_ARN" \
    '
      .ServerSideEncryption == "aws:kms" and
      .SSEKMSKeyId == $kms_key
    ' \
    "$head_response" \
    >/dev/null

  jq -e '
    .Retention.Mode != null and
    .Retention.RetainUntilDate != null
  ' "$retention_response" \
    >/dev/null

  jq -n \
    --arg local_path "$artifact" \
    --arg filename "$artifact_name" \
    --arg sha256 "$artifact_hash" \
    --arg bucket "$BUCKET" \
    --arg key "$artifact_key" \
    --arg version_id "$version_id" \
    --arg etag "$(jq -r '.ETag // empty' "$head_response")" \
    --arg encryption "$(jq -r '.ServerSideEncryption // empty' "$head_response")" \
    --arg kms_key_id "$(jq -r '.SSEKMSKeyId // empty' "$head_response")" \
    --arg retention_mode "$(jq -r '.Retention.Mode // empty' "$retention_response")" \
    --arg retain_until "$(jq -r '.Retention.RetainUntilDate // empty' "$retention_response")" \
    '{
      local_path: $local_path,
      filename: $filename,
      sha256: $sha256,
      s3: {
        bucket: $bucket,
        key: $key,
        version_id: $version_id,
        etag: $etag,
        encryption: $encryption,
        kms_key_id: $kms_key_id,
        retention: {
          mode: $retention_mode,
          retain_until: $retain_until
        }
      }
    }' \
    > "${ITEM_DIRECTORY}/$(printf '%04d' "$item_number").json"

  echo "VersionId: ${version_id}"
  echo "Encryption: aws:kms"
  echo "Retention: $(jq -r '.Retention.Mode' "$retention_response")"
  echo "Retain until: $(jq -r '.Retention.RetainUntilDate' "$retention_response")"
done

generated_at="$(
  date -u +%Y-%m-%dT%H:%M:%SZ
)"

jq -s \
  --arg generated_at "$generated_at" \
  --arg repository "${GITHUB_REPOSITORY:-local}" \
  --arg commit "${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}" \
  --arg run_id "${GITHUB_RUN_ID:-local}" \
  --arg run_attempt "${GITHUB_RUN_ATTEMPT:-local}" \
  --arg bucket "$BUCKET" \
  --arg prefix "$S3_PREFIX" \
  '{
    generated_at_utc: $generated_at,
    workflow: {
      repository: $repository,
      commit: $commit,
      run_id: $run_id,
      run_attempt: $run_attempt
    },
    destination: {
      bucket: $bucket,
      prefix: $prefix
    },
    artifacts: .
  }' \
  "$ITEM_DIRECTORY"/*.json \
  > "$RECEIPT_PATH"

echo
echo "PASS: Evidence artifacts were uploaded, versioned, encrypted, and retained."
echo "UPLOAD_RECEIPT=${RECEIPT_PATH}"
