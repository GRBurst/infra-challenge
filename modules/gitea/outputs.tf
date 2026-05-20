locals {
  # Hardcoded local-only credentials (mirror values.yaml gitea.admin.*).
  # See variables.tf for rationale.
  admin_user     = "gitea-admin"
  admin_password = "gitea-admin"
}

output "namespace" {
  description = "Namespace where Gitea was deployed."
  value       = kubernetes_namespace_v1.gitea.metadata[0].name
}

output "repo_url" {
  description = "Cluster-internal Git URL ArgoCD can pull from."
  value       = "http://gitea-http.${var.namespace}.svc.cluster.local:${var.service_port}/${local.admin_user}/${var.repo_name}.git"
}

output "push_url" {
  description = "Host-reachable Git URL (with credentials) for `git push`."
  value       = "http://${local.admin_user}:${local.admin_password}@localhost:${var.host_port}/${local.admin_user}/${var.repo_name}.git"
  sensitive   = true
}

output "web_url" {
  description = "Host-reachable Gitea web UI."
  value       = "http://localhost:${var.host_port}"
}

output "admin_user" {
  description = "Gitea admin username (also the repo owner)."
  value       = local.admin_user
}

output "repo_name" {
  description = "Repository name inside Gitea."
  value       = var.repo_name
}
