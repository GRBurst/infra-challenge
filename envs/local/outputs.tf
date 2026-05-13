output "greeter_namespace" {
  value = module.gitops.greeter_namespace
}

output "argocd_namespace" {
  value = module.gitops.argocd_namespace
}

output "argocd_port_forward_hint" {
  value = "kubectl --context ${var.kubeconfig_context} port-forward svc/argocd-server -n ${module.gitops.argocd_namespace} 8080:80"
}
