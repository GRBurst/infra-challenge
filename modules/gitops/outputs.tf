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
  value       = kubernetes_manifest.application.manifest.spec.source.repoURL
  description = "Effective repoURL of the greeter ArgoCD Application."
}

output "application_target_revision" {
  value = kubernetes_manifest.application.manifest.spec.source.targetRevision
}
