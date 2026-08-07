#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

TERRAFORM_DIR="${TERRAFORM_DIR:-${ROOT_DIR}/terraform}"
POLICY_DIR="${POLICY_DIR:-${ROOT_DIR}/policies}"

WORK_DIR="$(mktemp -d)"
PLAN_FILE="${WORK_DIR}/tfplan"
PLAN_JSON="${WORK_DIR}/plan.json"

cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

for command_name in terraform opa conftest jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: Required command is missing: ${command_name}" >&2
    exit 1
  fi
done

echo "===== OPA POLICY TESTS ====="

opa test "$POLICY_DIR"

echo
echo "===== TERRAFORM INITIALIZATION ====="

terraform \
  -chdir="$TERRAFORM_DIR" \
  init \
  -input=false \
  -no-color

echo
echo "===== TERRAFORM VALIDATION ====="

terraform \
  -chdir="$TERRAFORM_DIR" \
  validate \
  -no-color

echo
echo "===== TERRAFORM PLAN ====="

terraform \
  -chdir="$TERRAFORM_DIR" \
  plan \
  -input=false \
  -no-color \
  -out="$PLAN_FILE"

echo
echo "===== TERRAFORM PLAN JSON ====="

terraform \
  -chdir="$TERRAFORM_DIR" \
  show \
  -json \
  "$PLAN_FILE" \
  > "$PLAN_JSON"

jq -e '
  .format_version and
  .terraform_version and
  (.resource_changes | type == "array")
' "$PLAN_JSON" >/dev/null

echo "Resource changes: $(jq '.resource_changes | length' "$PLAN_JSON")"

echo
echo "===== CONFTEST POLICY GATE ====="

conftest test \
  "$PLAN_JSON" \
  --policy "$POLICY_DIR"

echo
echo "PASS: Terraform plan satisfies all five compliance policies."
