############################################################
# Customer-managed KMS key
#
# Supports:
# - GAP-01: S3 customer-managed encryption
# - GAP-02: DynamoDB customer-managed encryption
# - Evidence-vault encryption later in the capstone
############################################################

resource "aws_kms_key" "capstone" {
  description             = "CGE-P capstone key for patient data and compliance evidence"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-capstone-kms"
  }
}

resource "aws_kms_alias" "capstone" {
  name          = "alias/${local.name_prefix}-capstone-${local.suffix}"
  target_key_id = aws_kms_key.capstone.key_id
}
