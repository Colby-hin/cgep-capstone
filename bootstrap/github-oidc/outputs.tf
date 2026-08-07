output "github_oidc_provider_arn" {
  value       = local.github_oidc_provider_arn
  description = "AWS IAM OIDC provider trusted for GitHub Actions."
}

output "github_plan_role_arn" {
  value       = aws_iam_role.github_plan.arn
  description = "AWS role used for pull-request Terraform plans."
}

output "github_deploy_role_arn" {
  value       = aws_iam_role.github_deploy.arn
  description = "AWS role used for main-branch deployment and evidence upload."
}
