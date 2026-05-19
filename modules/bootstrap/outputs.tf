output "s3_bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.locks.name
}

output "ci_app_role_arn" {
  value       = aws_iam_role.ci_app_role.arn
  description = "OIDC-assumable role for CI image build & ECR push."
}

output "ci_infra_role_arn" {
  value       = aws_iam_role.ci_infra_role.arn
  description = "OIDC-assumable role for tofu apply (currently Admin; scoped later)."
}

output "ci_role_arn" {
  value       = aws_iam_role.ci_infra_role.arn
  description = "Deprecated alias for ci_infra_role_arn."
}
