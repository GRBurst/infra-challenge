output "greeter_namespace" {
  value = module.gitops.greeter_namespace
}

output "argocd_namespace" {
  value = module.gitops.argocd_namespace
}

output "argocd_port_forward_hint" {
  value = "kubectl --context ${var.kubeconfig_context} port-forward svc/argocd-server -n ${module.gitops.argocd_namespace} ${var.argocd_host_port}:80"
}

output "greeter_url" {
  value       = "http://localhost:${var.greeter_host_port}/"
  description = "Greeter service via Traefik ingress (mapped by k3d loadbalancer)."
}

output "argocd_target_revision" {
  value = var.greeter_branch
}

output "gitea_push_url" {
  value       = module.gitea.push_url
  description = "Host-reachable URL (with credentials) for `git push gitea ...`."
  sensitive   = true
}

output "gitea_web_url" {
  value       = module.gitea.web_url
  description = "Host-reachable Gitea web UI URL."
}
