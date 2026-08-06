# Capstone Design Decisions

## Governed system

This capstone governs the Acme Health Patient Intake API derived from the
official `GRCEngClub/cgep-app-starter` repository.

The existing serverless application remains functional while preventive,
detective, audit, and evidence controls are added around it.

## Primary framework

The primary framework is the HIPAA Security Rule because the application
receives and stores patient intake information that may contain electronic
protected health information.

The selected OSCAL controls cover:

- 45 CFR 164.308(a)(7), contingency planning
- 45 CFR 164.312(a)(1), access control
- 45 CFR 164.312(a)(2)(iv), encryption and decryption
- 45 CFR 164.312(b), audit controls
- 45 CFR 164.312(c)(1), integrity
- 45 CFR 164.312(e)(1), transmission security

## Technology decisions

| Area | Selection | Reason |
|---|---|---|
| Cloud provider | AWS | Matches the starter application and course sandbox |
| Region | `us-east-1` | Course sandbox deployment region |
| Infrastructure | Terraform | Repeatable and reviewable infrastructure-as-code |
| State | Versioned S3 backend with native lock file | Shared state, recovery, and serialized changes |
| Policy engine | OPA/Rego with Conftest | Fail-closed evaluation of Terraform JSON plans |
| CI authentication | GitHub OIDC | Short-lived AWS credentials without stored access keys |
| Signing | Keyless Cosign | Identity-bound evidence signatures |
| Evidence storage | KMS-encrypted S3 Object Lock vault | Versioned and retention-protected evidence |
| Audit logging | Multi-Region CloudTrail | Management-event visibility and log validation |
| Compliance format | OSCAL | Machine-readable control implementation |

## Encryption design

A customer-managed KMS key protects:

- Patient uploads
- DynamoDB intake records
- Compliance evidence

Automatic KMS key rotation is enabled.

The Lambda role receives only the KMS permissions required by the application:

- `kms:Encrypt`
- `kms:Decrypt`
- `kms:ReEncrypt*`
- `kms:GenerateDataKey*`
- `kms:DescribeKey`

## Least-privilege design

The Lambda inline policy permits only:

- `dynamodb:PutItem` for the intake table
- `s3:PutObject` for the uploads location
- Required operations on the capstone KMS key

The deployed policy does not allow `dynamodb:*` or `s3:*`.

GitHub Actions uses separate plan and deployment roles. Their trust policies
are restricted to this repository and approved GitHub OIDC subjects.

## Evidence design

`scripts/evidence-bundle.sh` creates a compliance evidence archive containing:

- Repository metadata
- Terraform validation and plan results
- OPA and Conftest results
- Live AWS configuration evidence
- A SHA-256 manifest
- An archive SHA-256 value

`scripts/evidence-upload.sh` verifies after upload:

- A non-null S3 `VersionId`
- `aws:kms` encryption using the capstone key
- Active Object Lock retention
- Recorded SHA-256 hashes

The deployment workflow is designed to sign the archive with keyless Cosign
before uploading it to the evidence vault.

## Implemented capstone layers

1. Terraform compliance baseline
2. Tested OPA/Rego policy suite
3. Conftest fail-closed gate
4. GitHub OIDC authentication roles
5. GitHub Actions workflow definitions
6. Cosign signing and verification workflow definition
7. KMS-encrypted Object Lock evidence vault
8. Evidence generation and upload utilities
9. OSCAL catalog, profile, and component definition
10. Multi-Region CloudTrail
11. Remote Terraform state with native locking

## Remaining live checkpoints

The following are not yet claimed as complete:

- Successful GitHub-hosted policy-gate run
- Successful deployment and evidence run
- Keyless Cosign verification result
- Evidence-vault upload receipt with version and retention data
- One compliant merged pull request
- One intentionally noncompliant blocked pull request
- Final merge into `main`

Cancelled or queued hosted runs are not treated as successful compliance
evidence.
