output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "S3 bucket used by the main Terraform configuration."
}

output "state_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "ARN of the Terraform state bucket."
}

output "state_key" {
  value       = "cgep-capstone/terraform.tfstate"
  description = "S3 object key used for the main Terraform state."
}
