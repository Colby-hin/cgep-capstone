## The Big Picture

This diagram shows how the capstone connects the AWS application, security controls, policy-as-code testing, CI/CD enforcement, evidence collection, and compliance traceability into one end-to-end GRC Engineering workflow.

<img width="1536" height="1024" alt="The big picture" src="https://github.com/user-attachments/assets/c7330cc0-cc72-43a3-bdeb-1165b012bab7" />


# CGE-P Capstone: Governed Patient Intake Pipeline

This repository adds an audit-defensible governance and compliance pipeline to an AWS serverless patient-intake application.

## Implemented capabilities

- Terraform-managed AWS infrastructure
- Customer-managed KMS encryption for Amazon S3 and DynamoDB
- TLS-only access to the patient uploads bucket
- S3 versioning and public-access blocking
- Least-privilege Lambda IAM permissions
- Lambda deployed in private VPC subnets with S3 and DynamoDB gateway endpoints
- Multi-Region AWS CloudTrail with log-file validation
- KMS-encrypted S3 Object Lock evidence vault
- Versioned S3 Terraform backend with native state locking
- GitHub OIDC roles with repository-restricted trust policies
- Five OPA/Rego compliance policies (enforcing six Terraform remediations)
- Ten passing Rego unit tests
- Conftest enforcement against the real Terraform plan
- Compliance evidence generation and vault-upload utilities
- OSCAL catalog, profile, and component definition

## Repository structure

```text
.github/workflows/
  grc-gate.yml


bootstrap/
  backend/
  github-oidc/

docs/
  control-mapping.md
  design-decisions.md

oscal/
  hipaa-security-rule-catalog.json
  hipaa-security-rule-profile.json
  components/
        component-definition.json

policies/
  helpers.rego
  s3_kms.rego
  dynamodb_kms.rego
  s3_tls.rego
  s3_versioning.rego
  iam_least_privilege.rego
  *_test.rego

scripts/
  policy-gate.sh
  evidence-bundle.sh
  evidence-upload.sh

terraform/
  AWS application and compliance infrastructure
```

## HIPAA control scope

The implementation maps technical safeguards to the following HIPAA Security Rule requirements:

- 45 CFR 164.308(a)(7), contingency planning and recoverability
- 45 CFR 164.312(a)(1), access control
- 45 CFR 164.312(a)(2)(iv), encryption and decryption
- 45 CFR 164.312(b), audit controls
- 45 CFR 164.312(c)(1), integrity
- 45 CFR 164.312(e)(1), transmission security

See [docs/control-mapping.md](docs/control-mapping.md) for the detailed control-to-implementation mapping.

## Implemented security controls

### Encryption

A customer-managed AWS KMS key protects:

- Patient-upload objects in Amazon S3
- Patient-intake records in DynamoDB
- Compliance evidence stored in the evidence vault

Automatic KMS key rotation is enabled.

### Transport security

The patient uploads bucket has a resource policy that denies requests when `aws:SecureTransport` is `false`.

### Recoverability

S3 versioning is enabled for:

- Patient uploads
- Compliance evidence
- CloudTrail logs
- Terraform remote state

### Least privilege

The Lambda execution policy is limited to the operations required by the application:

- `dynamodb:PutItem`
- `s3:PutObject`
- Required KMS encryption and decryption actions

The policy does not grant `dynamodb:*` or `s3:*`.

### Audit logging

A Multi-Region CloudTrail records management activity, includes global service events, validates log-file integrity, and delivers logs to a dedicated versioned S3 bucket.

### Immutable evidence

The compliance evidence vault uses:

- S3 Object Lock
- Governance-mode retention
- S3 versioning
- Customer-managed KMS encryption
- Public-access blocking
- TLS-only access

## Policy-as-code

The Rego policy suite denies Terraform plans that fail to provide:

1. Customer-managed KMS encryption for patient uploads
2. Customer-managed KMS encryption for DynamoDB
3. TLS-only access to the uploads bucket
4. S3 versioning for patient uploads
5. Least-privilege Lambda data permissions

Each policy has one compliant test and one noncompliant test.

Verified local unit-test result:

```text
PASS: 10/10
```

Verified Conftest result against the real Terraform plan:

```text
5 tests, 5 passed, 0 warnings, 0 failures, 0 exceptions
PASS: Terraform plan satisfies all five compliance policies.
```

## Local verification

Configure the course sandbox environment:

```bash
export AWS_PROFILE="lab23-sandbox"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"
export PATH="$HOME/.local/bin:$PATH"
```

Run Rego validation and unit tests:

```bash
opa check --strict policies
opa test policies
```

Run the complete Terraform and Conftest gate:

```bash
./scripts/policy-gate.sh
```

Generate a local evidence archive:

```bash
mkdir -p /tmp/cgep-evidence
./scripts/evidence-bundle.sh /tmp/cgep-evidence
```

Validate an evidence upload without writing objects:

```bash
VALIDATE_ONLY=1 \
  ./scripts/evidence-upload.sh \
    example-bucket \
    arn:aws:kms:us-east-1:000000000000:key/example \
    evidence/example \
    /path/to/evidence-archive.tar.gz
```

## Evidence generation

`scripts/evidence-bundle.sh` captures:

- Git repository and commit metadata
- Terraform validation results
- Terraform plan metadata
- OPA strict-check results
- OPA unit-test results
- Conftest results
- S3 encryption and versioning configuration
- S3 TLS policy configuration
- DynamoDB KMS configuration
- KMS key metadata and rotation status
- Lambda IAM policy configuration
- CloudTrail configuration and logging status
- Evidence-vault encryption and Object Lock configuration
- A SHA-256 manifest for all evidence files
- A SHA-256 value for the final archive

`scripts/evidence-upload.sh` verifies after each upload:

- A non-null S3 `VersionId`
- `aws:kms` server-side encryption
- Use of the capstone KMS key
- Active Object Lock retention
- A recorded artifact SHA-256 value

## GitHub Actions

### GRC Policy Gate

`.github/workflows/grc-gate.yml` is designed to perform:

1. Repository checkout
2. Terraform installation
3. OPA and Conftest installation
4. GitHub OIDC authentication
5. Terraform formatting and validation
6. Rego formatting, strict checking, and unit tests
7. Terraform plan generation
8. Conftest enforcement

### GRC Deploy and Evidence

`.github/workflows/grc-gate.yml` is designed to perform:

1. Terraform plan
2. Conftest gate
3. Terraform apply
4. Evidence-bundle generation
5. Keyless Cosign signing
6. Cosign identity verification
7. Upload to the S3 Object Lock evidence vault
8. S3 version, encryption, and retention receipt generation

The consolidated `grc-gate.yml` workflow passed YAML parsing and Actionlint static validation.

## Terraform state governance

The application state was migrated from local storage to a versioned S3 backend.

The backend includes:

- S3 server-side encryption
- Versioning
- Public-access blocking
- TLS-only access
- Native Terraform lock-file support

Post-migration Terraform planning reported no infrastructure changes.

## GitHub OIDC

GitHub Actions uses short-lived AWS credentials through GitHub OIDC.

Two IAM roles separate responsibilities:

- A plan role for Terraform planning, state reads, and lock-file operations
- A deployment role for reviewed infrastructure changes and evidence uploads

The trust policies are restricted to the capstone repository and approved GitHub subjects. No permanent AWS access keys are stored in the repository or workflow files.

## OSCAL

The `oscal/` directory contains:

- A HIPAA Security Rule control catalog
- A selected HIPAA control profile
- An OSCAL component definition

The component definition maps controls to:

- Terraform resource addresses
- Rego policy files
- Evidence artifact paths

All three documents passed the official OSCAL v1.2.2 JSON schemas.

## Current status

The following are implemented and locally verified:

- AWS application infrastructure
- Six Terraform security remediations
- Customer-managed KMS encryption
- Least-privilege Lambda IAM
- CloudTrail audit logging
- S3 Object Lock evidence vault
- Remote Terraform state
- GitHub OIDC IAM roles
- Rego policy suite
- Ten Rego unit tests
- Real-plan Conftest evaluation
- Local compliance policy gate
- Evidence-bundle generation
- Archive and manifest hash validation
- Evidence-upload input validation
- OSCAL schema validation
- GitHub Actions static validation

The following live proofs have been completed:

- Successful GitHub-hosted policy-gate run
- Successful deployment and evidence workflow run
- Verified keyless Cosign result
- Immutable evidence-vault upload receipt
- One compliant merged pull request
- One intentionally noncompliant blocked pull request
Cancelled or queued GitHub-hosted runs are not presented as successful compliance evidence.

## Documentation

- [Implementation write-up](WRITEUP.md)
- [Control mapping](docs/control-mapping.md)
- [Design decisions](docs/design-decisions.md)
- [OSCAL component definition](oscal/components/component-definition.json)
