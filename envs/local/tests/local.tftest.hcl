mock_provider "helm" {}
mock_provider "kubernetes" {}

run "module_emits_greeter_namespace" {
  command = plan
  assert {
    condition     = output.greeter_namespace == "greeter"
    error_message = "gitops module must default to greeter namespace"
  }
}

run "module_emits_port_forward_hint_for_local_context" {
  command = plan
  assert {
    condition     = strcontains(output.argocd_port_forward_hint, "k3d-infra-challenge")
    error_message = "Port-forward hint must reference k3d-infra-challenge context."
  }
}
