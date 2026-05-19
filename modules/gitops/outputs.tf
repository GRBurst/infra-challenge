output "argocd_namespace" {
  value = var.argocd_namespace
}

output "greeter_namespace" {
  value = var.greeter_namespace
}

output "application_name" {
  value = "greeter"
}

output "application_repo_url" {
  value       = try(kubernetes_manifest.application[0].manifest.spec.source.repoURL, null)
  description = "Effective repoURL of the greeter ArgoCD Application. Null when create_apps = false."
}

output "application_target_revision" {
  value = try(kubernetes_manifest.application[0].manifest.spec.source.targetRevision, null)
}
