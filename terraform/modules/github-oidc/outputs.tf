output "role_arn" {
  description = "IAM role ARN for GitHub Actions (set this as AWS_ROLE_ARN secret)"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
