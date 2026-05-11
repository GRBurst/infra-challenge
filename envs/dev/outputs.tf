output "dev_state_bucket" {
  value = module.bootstrap.s3_bucket_name
}

output "dev_dynamo_table" {
  value = module.bootstrap.dynamodb_table_name
}
