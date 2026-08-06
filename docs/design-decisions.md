# Capstone Design Decisions

## Governed system

This capstone governs the Acme Health Patient Intake API from the official
`GRCEngClub/cgep-app-starter` repository. The existing application remains
functional while governance, security, compliance, and evidence controls are
added around it.

## Primary framework

The primary framework is the HIPAA Security Rule because the application
receives and stores patient intake information that may contain protected
health information.

## Deployment decisions

| Decision | Selection |
|---|---|
| Cloud provider | AWS |
| AWS region | `us-east-1` |
| Deployment account | Course sandbox account |
| Infrastructure management | Terraform |
| Policy engine | OPA/Rego with Conftest |
| Evidence signing | Cosign keyless signing |
| Evidence storage | KMS-encrypted S3 Object Lock vault |
| Object Lock mode | Governance |
| Pull-request behavior | Plan and policy evaluation |
| Main-branch behavior | Apply, capture, sign, and upload evidence |

## Initial gap-remediation scope

The implementation will close these named starter gaps:

1. GAP-01 — Encrypt the uploads bucket with a customer-managed KMS key.
2. GAP-02 — Encrypt the DynamoDB table with a customer-managed KMS key.
3. GAP-03 — Deny non-TLS requests to the uploads bucket.
4. GAP-04 — Enable versioning on the uploads bucket.
5. GAP-07 — Replace broad Lambda data permissions with least-privilege actions.

## Required capstone layers

1. Terraform compliance baseline
2. Tested OPA/Rego policy suite
3. Conftest fail-closed policy gate
4. GitHub Actions evidence pipeline
5. Cosign signature and certificate
6. Immutable S3 evidence storage
7. OSCAL component and profile
8. Stakeholder and grader documentation
