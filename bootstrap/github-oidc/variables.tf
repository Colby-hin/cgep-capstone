variable "aws_region" {
  description = "AWS Region used by the capstone."
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format."
  }
}

variable "create_oidc_provider" {
  description = "Create GitHub's AWS OIDC provider when it is not already present."
  type        = bool
}

variable "state_bucket_name" {
  description = "S3 bucket containing Terraform remote state."
  type        = string
}

variable "evidence_bucket_name" {
  description = "S3 Object Lock bucket receiving signed evidence."
  type        = string
}

variable "capstone_kms_key_arn" {
  description = "Customer-managed KMS key protecting capstone evidence."
  type        = string
}
