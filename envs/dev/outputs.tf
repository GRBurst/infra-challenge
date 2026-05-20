output "dev_state_bucket" {
  value = module.bootstrap.s3_bucket_name
}

output "dev_dynamo_table" {
  value = module.bootstrap.dynamodb_table_name
}

output "ci_app_role_arn" {
  value = module.bootstrap.ci_app_role_arn
}

output "ci_infra_role_arn" {
  value = module.bootstrap.ci_infra_role_arn
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "ecr_repository_url" {
  value = module.platform.ecr_repository_url
}

output "ecr_registry_host" {
  value = module.platform.ecr_registry_host
}

output "greeter_namespace" {
  value = module.gitops.greeter_namespace
}

output "cluster_admin_role_arn" {
  value = module.platform.cluster_admin_role_arn
}

output "greeter_log_group" {
  value       = module.platform.greeter_log_group
  description = "CloudWatch Logs group for greeter application logs (populated by the Fluent Bit DaemonSet)."
}

output "greeter_alarm_name" {
  value       = module.platform.greeter_alarm_name
  description = "CloudWatch alarm that fires when the greeter has <1 running container for 2 minutes."
}
