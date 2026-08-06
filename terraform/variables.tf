variable "aws_region" {
  type        = string
  description = "AWS region for the starter."
  default     = "us-east-1"
}

variable "evidence_retention_days" {
  description = "Default Governance-mode Object Lock retention for capstone evidence."
  type        = number
  default     = 7

  validation {
    condition     = var.evidence_retention_days >= 1
    error_message = "Evidence retention must be at least one day."
  }
}
