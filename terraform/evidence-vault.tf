############################################################
# Immutable capstone evidence vault
#
# Provides:
# - Customer-managed KMS encryption
# - S3 Object Lock in Governance mode
# - Versioning and durable VersionIds
# - Public-access blocking
# - TLS-only access
############################################################

resource "aws_s3_bucket" "evidence_vault" {
  bucket              = "${local.name_prefix}-evidence-${local.suffix}"
  object_lock_enabled = true
  force_destroy       = false

  tags = {
    Name            = "${local.name_prefix}-evidence-vault"
    Purpose         = "audit-evidence"
    Environment     = "capstone"
    ComplianceScope = "HIPAA"
  }
}

resource "aws_s3_bucket_versioning" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.capstone.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.evidence_retention_days
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.evidence_vault
  ]
}

resource "aws_s3_bucket_policy" "evidence_vault_tls" {
  bucket = aws_s3_bucket.evidence_vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.evidence_vault.arn,
          "${aws_s3_bucket.evidence_vault.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.evidence_vault
  ]
}
