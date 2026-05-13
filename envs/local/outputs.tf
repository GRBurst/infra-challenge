output "greeter_namespace" {
  value = module.gitops.greeter_namespace
}

output "argocd_namespace" {
  value = module.gitops.argocd_namespace
}

output "argocd_port_forward_hint" {
  value = "kubectl --context ${var.kubeconfig_context} port-forward svc/argocd-server -n ${module.gitops.argocd_namespace} 8080:80"
}

output "argocd_target_revision" {
  value = local.greeter_target_rev
}

output "gitea_push_url" {
  value       = var.gitea_enabled ? local.gitea_host_url : ""
  description = "Host-reachable URL for `git push gitea ...`. Empty when gitea_enabled=false."
}

output "gitea_web_url" {
  value       = var.gitea_enabled ? "http://localhost:3000" : ""
  description = "Gitea web UI URL. Empty when gitea_enabled=false."
}
