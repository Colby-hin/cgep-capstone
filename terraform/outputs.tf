output "api_url" {
  value       = "${aws_apigatewayv2_api.intake.api_endpoint}/intake"
  description = "POST /intake endpoint."
}

output "intake_table" {
  value       = aws_dynamodb_table.intake.name
  description = "DynamoDB table holding patient submissions."
}

output "uploads_bucket" {
  value       = aws_s3_bucket.uploads.id
  description = "S3 bucket where intake attachments land."
}

output "lambda_function_name" {
  value = aws_lambda_function.intake.function_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "capstone_kms_key_arn" {
  value       = aws_kms_key.capstone.arn
  description = "ARN of the customer-managed KMS key used by the capstone."
}

output "capstone_kms_alias" {
  value       = aws_kms_alias.capstone.name
  description = "Alias of the customer-managed KMS key used by the capstone."
}

output "evidence_vault_bucket" {
  value       = aws_s3_bucket.evidence_vault.id
  description = "Name of the KMS-encrypted S3 Object Lock evidence vault."
}

output "evidence_vault_arn" {
  value       = aws_s3_bucket.evidence_vault.arn
  description = "ARN of the S3 Object Lock evidence vault."
}

output "evidence_retention_days" {
  value       = var.evidence_retention_days
  description = "Default Governance-mode evidence retention period."
}
