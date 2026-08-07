# Governed Patient Intake Capstone Write-Up

## Executive summary

This capstone uses the HIPAA Security Rule as its primary compliance framework and converts the AWS serverless Patient Intake API into a governed delivery system with preventive controls, detective controls, policy-as-code, immutable signed evidence, and machine-readable OSCAL compliance mappings.

The implementation remediates six security gaps in the starter environment:

1. Patient uploads lacked customer-managed KMS encryption.
2. DynamoDB intake records lacked customer-managed KMS encryption.
3. The uploads bucket did not explicitly deny insecure transport.
4. The uploads bucket did not have versioning enabled.
5. The intake Lambda was not deployed inside the existing private VPC.
6. The Lambda execution policy was broader than required.

Five remediations are enforced through tested Rego policies. Private VPC placement is implemented through Terraform and verified through deployment and workload testing.

## System scope

The governed application is the Acme Health Patient Intake API.

The application uses:

- Amazon API Gateway
- AWS Lambda
- Amazon DynamoDB
- Amazon S3
- AWS KMS
- AWS IAM
- AWS CloudTrail

The delivery and compliance system also uses:

- Terraform
- OPA and Rego
- Conftest
- GitHub Actions
- GitHub OIDC
- Cosign
- OSCAL
- S3 Object Lock

## HIPAA control scope

The implementation maps technical controls to:

- 45 CFR 164.308(a)(7), contingency planning and recoverability
- 45 CFR 164.312(a)(1), access control
- 45 CFR 164.312(a)(2)(iv), encryption and decryption
- 45 CFR 164.312(b), audit controls
- 45 CFR 164.312(c)(1), integrity
- 45 CFR 164.312(e)(1), transmission security

Detailed mappings are maintained in `docs/control-mapping.md` and `oscal/components/component-definition.json`.

## Infrastructure remediation

### GAP-05 — Private VPC placement

The intake Lambda now runs in two private subnets in the existing starter VPC. A dedicated security group restricts outbound traffic to HTTPS, while S3 and DynamoDB gateway endpoints preserve private service access without a NAT gateway. Live tests confirmed both DynamoDB submission writes and KMS-encrypted S3 attachment uploads.

### Customer-managed encryption

A customer-managed KMS key protects:

- Patient-upload objects in Amazon S3
- Patient-intake records in DynamoDB
- Compliance evidence stored in the evidence vault

Automatic KMS key rotation is enabled.

Relevant Terraform resources include:

- `aws_kms_key.capstone`
- `aws_s3_bucket_server_side_encryption_configuration.uploads`
- `aws_dynamodb_table.intake`

Live AWS verification confirmed that the uploads bucket uses `aws:kms`, DynamoDB server-side encryption is active, and KMS rotation is enabled.

### TLS-only access

The uploads bucket policy denies requests when `aws:SecureTransport` is `false`.

Relevant Terraform resource:

- `aws_s3_bucket_policy.uploads_tls`

This prevents unencrypted HTTP access to patient-upload objects.

### Versioning and recovery

Versioning is enabled for:

- Patient uploads
- Compliance evidence
- CloudTrail logs
- Terraform remote state

Relevant Terraform resources include:

- `aws_s3_bucket_versioning.uploads`
- `aws_s3_bucket_versioning.evidence_vault`
- `aws_s3_bucket_versioning.cloudtrail_logs`

Versioning supports recovery from accidental object replacement or deletion and preserves prior evidence and state versions.

### Least-privilege Lambda permissions

The Lambda inline policy permits only the data operations required by the intake handler:

- `dynamodb:PutItem`
- `s3:PutObject`
- Required KMS encryption and decryption operations

Relevant Terraform resources:

- `aws_iam_role.lambda`
- `aws_iam_role_policy.lambda_inline`

The deployed policy does not allow `dynamodb:*` or `s3:*`.

## Policy-as-code

Five Rego policies evaluate the Terraform JSON plan.

| Policy | Control enforced |
|---|---|
| `policies/s3_kms.rego` | Customer-managed KMS encryption for uploads |
| `policies/dynamodb_kms.rego` | Customer-managed KMS encryption for DynamoDB |
| `policies/s3_tls.rego` | TLS-only uploads-bucket access |
| `policies/s3_versioning.rego` | Uploads-bucket versioning |
| `policies/iam_least_privilege.rego` | Least-privilege Lambda data permissions |

Each policy includes one compliant and one noncompliant unit test.

Verified OPA result:

```text
PASS: 10/10
```

The real Terraform plan also passed Conftest:

```text
5 tests, 5 passed, 0 warnings, 0 failures, 0 exceptions
PASS: Terraform plan satisfies all five compliance policies.
```

The local fail-closed gate is implemented in `scripts/policy-gate.sh`.

## Audit logging

A Multi-Region CloudTrail records AWS management activity.

The trail:

- Includes global service events
- Uses log-file validation
- Delivers logs to a dedicated S3 bucket
- Stores logs in a versioned bucket
- Is actively logging

Relevant Terraform resources include:

- `aws_cloudtrail.capstone`
- `aws_s3_bucket.cloudtrail_logs`
- `aws_s3_bucket_versioning.cloudtrail_logs`

Live AWS verification confirmed that CloudTrail log objects were delivered successfully.

## Immutable evidence vault

The evidence vault uses:

- S3 Object Lock
- Governance-mode retention
- Seven-day default retention
- S3 versioning
- Customer-managed KMS encryption
- Public-access blocking
- TLS-only access

Relevant Terraform resources include:

- `aws_s3_bucket.evidence_vault`
- `aws_s3_bucket_object_lock_configuration.evidence_vault`
- `aws_s3_bucket_versioning.evidence_vault`
- `aws_s3_bucket_server_side_encryption_configuration.evidence_vault`

## Evidence generation

`scripts/evidence-bundle.sh` generates a compliance evidence archive containing:

- Repository and commit metadata
- Terraform validation output
- Terraform plan metadata
- OPA strict-check output
- OPA unit-test output
- Conftest results
- S3 encryption and versioning configuration
- S3 TLS-policy configuration
- DynamoDB encryption configuration
- KMS metadata and rotation status
- Lambda IAM policy evidence
- CloudTrail configuration and logging status
- Evidence-vault Object Lock configuration
- A SHA-256 manifest
- A SHA-256 value for the final archive

The evidence generator was executed locally. The resulting archive and internal manifest passed SHA-256 verification.

## Evidence upload

`scripts/evidence-upload.sh` uploads supplied artifacts to the evidence vault and verifies:

- A non-null S3 `VersionId`
- `aws:kms` encryption
- Use of the capstone KMS key
- Active Object Lock retention
- A retain-until date
- The local SHA-256 value

The uploader has been validated locally using its validation-only mode. The final live upload will be performed by the deployment workflow after evidence signing.

## Terraform state governance

The original Terraform state was migrated from local storage to a versioned S3 backend.

The backend includes:

- S3 server-side encryption
- S3 versioning
- Public-access blocking
- TLS-only access
- Native Terraform lock-file support

Post-migration Terraform planning reported no infrastructure changes.

## GitHub OIDC

GitHub Actions uses short-lived AWS credentials through GitHub OIDC.

Two IAM roles separate responsibilities:

### Plan role

The plan role provides:

- AWS read access required for Terraform planning
- Terraform state read access
- Terraform lock-file permissions

### Deployment role

The deployment role provides:

- Course-sandbox deployment permissions
- Terraform state access
- Evidence-vault upload and verification access
- Access to the capstone KMS key
- Scoped IAM administration for capstone roles

The trust policies are restricted to the capstone repository and approved GitHub subjects.

No permanent AWS access key is stored in the repository or workflow files.

## GitHub Actions workflows

### GRC Policy Gate

`.github/workflows/grc-gate.yml` performs:

1. Repository checkout
2. Terraform installation
3. OPA and Conftest installation
4. GitHub OIDC authentication
5. Terraform formatting and validation
6. Rego strict checking and unit tests
7. Terraform plan generation
8. Conftest enforcement

### GRC Deploy and Evidence

`.github/workflows/grc-gate.yml` is designed to perform:

1. Terraform plan
2. Conftest gate
3. Terraform apply
4. Evidence generation
5. Keyless Cosign signing
6. Cosign identity verification
7. Upload to the Object Lock vault
8. Version, encryption, and retention receipt generation

The consolidated `grc-gate.yml` workflow passed YAML parsing and Actionlint static validation.

## OSCAL implementation

The repository contains:

- `oscal/hipaa-security-rule-catalog.json`
- `oscal/hipaa-security-rule-profile.json`
- `oscal/components/component-definition.json`

The component definition maps HIPAA controls to:

- Terraform resource addresses
- Rego policy files
- Evidence artifact paths

All three documents passed the official OSCAL v1.2.2 JSON schemas.

## Validation completed

The following checks completed successfully:

- Terraform formatting and validation
- Terraform convergence planning
- Live patient-intake API test
- Live attachment-upload test
- S3 KMS encryption verification
- S3 versioning verification
- S3 TLS-policy verification
- DynamoDB KMS verification
- KMS rotation verification
- Lambda least-privilege verification
- Evidence-vault Object Lock verification
- CloudTrail configuration verification
- CloudTrail log-delivery verification
- OPA strict checking
- Ten OPA unit tests
- Conftest evaluation of the real Terraform plan
- Local fail-closed policy gate
- Local evidence-bundle generation
- Evidence archive and manifest verification
- Evidence-upload input validation
- OSCAL v1.2.2 schema validation
- GitHub Actions YAML validation
- Actionlint workflow validation

## Completed live verification

The following have been completed:

- Successful GitHub-hosted policy-gate execution
- Successful deployment and evidence workflow execution
- Keyless Cosign signing and verification result
- Live immutable evidence upload receipt
- One compliant merged pull request
- One intentionally noncompliant blocked pull request


The newest signed evidence bundle can be verified directly from the vault:

- **Object:** `s3://acme-health-intake-evidence-e8072135/evidence/Colby-hin/cgep-capstone/1feba8c0fe81fe09e3bf6b126eee3290606a42ce/run-31142670369-attempt-1/cgep-evidence-31142670369-20260807T025524Z.tar.gz`
- **Object Lock retention:** GOVERNANCE mode, retain-until 2026-08-14 (confirmed via `s3api get-object-retention`).
- **SHA-256:** recomputes to the value in the committed `.sha256` sidecar.
- **Cosign:** `cosign verify-blob --bundle <bundle>.sigstore.json --certificate-identity-regexp 'github.com/Colby-hin/cgep-capstone' --certificate-oidc-issuer https://token.actions.githubusercontent.com` returns `Verified OK`.

## Grader verification

A grader can perform local policy verification with:

```bash
opa check --strict policies
opa test policies
./scripts/policy-gate.sh
```

Workflow files can be validated with:

```bash
actionlint
```

OSCAL JSON syntax can be checked with:

```bash
jq empty \
  oscal/hipaa-security-rule-catalog.json \
  oscal/hipaa-security-rule-profile.json \
  oscal/components/component-definition.json
```

The primary grader-facing files are:

- `README.md`
- `WRITEUP.md`
- `docs/control-mapping.md`
- `docs/design-decisions.md`
- `oscal/components/component-definition.json`
- `.github/workflows/grc-gate.yml`
- `.github/workflows/grc-gate.yml`
- `scripts/policy-gate.sh`
- `scripts/evidence-bundle.sh`
- `scripts/evidence-upload.sh`

## Limitations

- The environment is a temporary course sandbox rather than a production AWS organization.
- The evidence vault uses governance mode with a seven-day default retention period.
- The OSCAL catalog is a capstone-specific HIPAA selection, not a complete reproduction of every HIPAA Security Rule provision.
