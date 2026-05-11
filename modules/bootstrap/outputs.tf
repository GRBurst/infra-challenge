output "s3_bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.locks.name
}

output "ci_role_arn" {
  value = aws_iam_role.ci_role.arn
}
