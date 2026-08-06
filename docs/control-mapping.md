# Control Mapping

A control is marked `Implemented` only after its Terraform deployment,
policy tests, and evidence checks succeed.

| Gap | Technical control | HIPAA reference | Terraform target | Status |
|---|---|---|---|---|
| GAP-01 | Customer-managed KMS encryption for S3 | 164.312(a)(2)(iv) | Uploads bucket | Planned |
| GAP-02 | Customer-managed KMS encryption for DynamoDB | 164.312(a)(2)(iv) | Intake table | Planned |
| GAP-03 | Deny requests without secure transport | 164.312(e)(1) | Uploads bucket policy | Planned |
| GAP-04 | Enable object versioning | 164.308(a)(7) | Uploads bucket versioning | Planned |
| GAP-07 | Least-privilege Lambda data access | 164.312(a)(1) | Lambda inline IAM policy | Planned |
