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
