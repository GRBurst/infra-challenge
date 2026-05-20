output "cluster_name" {
  value = var.create ? module.eks.cluster_name : ""
}

output "cluster_endpoint" {
  value = var.create ? module.eks.cluster_endpoint : ""
}

output "cluster_certificate_authority_data" {
  value = var.create ? module.eks.cluster_certificate_authority_data : ""
}

output "ecr_repository_url" {
  value = var.create ? aws_ecr_repository.greeter[0].repository_url : ""
}

output "ecr_registry_host" {
  # Used by CI for docker login; full URL is used for tagging.
  value = var.create ? split("/", aws_ecr_repository.greeter[0].repository_url)[0] : ""
}

output "vpc_id" {
  value = var.create ? module.vpc.vpc_id : ""
}

output "private_subnet_ids" {
  value = var.create ? module.vpc.private_subnets : []
}

output "cluster_admin_role_arn" {
  value       = var.create && length(var.cluster_admin_arns) > 0 ? aws_iam_role.cluster_admin[0].arn : ""
  description = "Assume this role for kubectl access: aws eks update-kubeconfig --role-arn <this>"
}

output "cluster_admin_arns" {
  description = "Echoes input for testability."
  value       = var.cluster_admin_arns
}

output "greeter_log_group" {
  value       = var.create ? aws_cloudwatch_log_group.greeter[0].name : ""
  description = "CloudWatch Logs group for greeter application logs (populated by the Fluent Bit DaemonSet)."
}

output "greeter_alarm_name" {
  value       = var.create ? aws_cloudwatch_metric_alarm.greeter_downtime[0].alarm_name : ""
  description = "CloudWatch alarm that fires when the greeter has <1 running container for 2 minutes."
}

output "console_admin_role_arn" {
  value       = var.create && length(var.console_admin_arns) > 0 ? aws_iam_role.console_admin[0].arn : ""
  description = "Assume this role for AWS EKS console access."
}
