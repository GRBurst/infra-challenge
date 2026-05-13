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

run "default_uses_github_repo_url" {
  command = plan
  assert {
    condition = strcontains(
      module.gitops.application_repo_url,
      "github.com/GRBurst/infra-challenge"
    )
    error_message = "When gitea_enabled=false, repo URL must remain GitHub."
  }
}

run "gitea_enabled_switches_repo_url_and_branch" {
  command = plan
  variables {
    gitea_enabled  = true
    greeter_branch = "feature/demo-x"
  }
  assert {
    condition     = output.argocd_target_revision == "feature/demo-x"
    error_message = "Application targetRevision must equal greeter_branch when set."
  }
  assert {
    condition = strcontains(
      output.gitea_push_url,
      "localhost:3000"
    )
    error_message = "gitea_push_url must expose localhost:3000 for host pushes."
  }
  assert {
    condition = strcontains(
      module.gitops.application_repo_url,
      "gitea-http.gitea.svc.cluster.local"
    )
    error_message = "When gitea_enabled=true, repoURL must use in-cluster Gitea DNS."
  }
}

run "gitea_disabled_emits_no_push_url" {
  command = plan
  assert {
    condition     = output.gitea_push_url == ""
    error_message = "gitea_push_url must be empty when gitea_enabled=false."
  }
}

run "rejects_empty_branch_when_gitea_enabled" {
  command = plan
  variables {
    gitea_enabled  = true
    greeter_branch = ""
  }
  expect_failures = [terraform_data.validate_gitea_inputs]
}
