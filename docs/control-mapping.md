# Control Mapping

A control is marked **Implemented** only after its Terraform deployment, policy
tests, and live AWS verification succeed.

| Gap | Technical control | HIPAA reference | Terraform resource | Rego policy | Status |
|---|---|---|---|---|---|
| GAP-01 | Customer-managed KMS encryption for patient uploads | 45 CFR 164.312(a)(2)(iv) | `aws_s3_bucket_server_side_encryption_configuration.uploads` | `policies/s3_kms.rego` | Implemented |
| GAP-02 | Customer-managed KMS encryption for intake records | 45 CFR 164.312(a)(2)(iv) | `aws_dynamodb_table.intake` | `policies/dynamodb_kms.rego` | Implemented |
| GAP-03 | Deny non-TLS access to the uploads bucket | 45 CFR 164.312(e)(1) | `aws_s3_bucket_policy.uploads_tls` | `policies/s3_tls.rego` | Implemented |
| GAP-04 | Enable versioning for patient uploads | 45 CFR 164.308(a)(7) | `aws_s3_bucket_versioning.uploads` | `policies/s3_versioning.rego` | Implemented |
| GAP-05 | Deploy Lambda in existing VPC private subnets | 45 CFR 164.312(a)(1) | `aws_lambda_function.intake`, `aws_security_group.lambda`, `aws_vpc_endpoint.s3`, `aws_vpc_endpoint.dynamodb` | Live AWS verification | Implemented |
| GAP-07 | Replace broad Lambda permissions with least privilege | 45 CFR 164.312(a)(1) | `aws_iam_role_policy.lambda_inline` | `policies/iam_least_privilege.rego` | Implemented |

## Supporting controls

| Control | HIPAA reference | Terraform resources | Status |
|---|---|---|---|
| Multi-Region CloudTrail with log validation | 45 CFR 164.312(b) | `aws_cloudtrail.capstone`, `aws_s3_bucket.cloudtrail_logs` | Implemented |
| KMS-encrypted immutable evidence vault | 45 CFR 164.312(c)(1) | `aws_s3_bucket.evidence_vault`, `aws_s3_bucket_object_lock_configuration.evidence_vault` | Implemented |
| Customer-managed KMS key with rotation | 45 CFR 164.312(a)(2)(iv) | `aws_kms_key.capstone` | Implemented |
| Versioned remote Terraform state with native locking | Configuration integrity and recoverability | `bootstrap/backend`, `terraform/backend.tf` | Implemented |
| Repository-restricted GitHub OIDC roles | 45 CFR 164.312(a)(1) | `bootstrap/github-oidc` | Implemented |
| Machine-readable OSCAL control mappings | Assessment and audit support | `oscal/components/component-definition.json` | Implemented |

## Verification evidence

`scripts/evidence-bundle.sh` captures:

- OPA strict-check and unit-test results
- Conftest results against the real Terraform plan
- Terraform validation and plan metadata
- S3 encryption, versioning, access-block, and TLS-policy evidence
- DynamoDB KMS encryption evidence
- KMS rotation evidence
- Lambda IAM policy evidence
- CloudTrail configuration and logging status
- Evidence-vault encryption, versioning, and Object Lock configuration
- A SHA-256 manifest covering the evidence files

The hosted GitHub workflow, Cosign signature, final vault-upload receipt, and PR
demonstrations remain live verification checkpoints and are not claimed as
complete yet.
