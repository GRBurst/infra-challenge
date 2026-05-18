mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  greeter_branch = "feature/demo-x"
}

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

run "always_provisions_gitea_in_gitea_namespace" {
  command = plan
  assert {
    condition     = module.gitea.namespace == "gitea"
    error_message = "Local env must always provision Gitea in the gitea namespace."
  }
}

run "argocd_application_points_at_in_cluster_gitea" {
  command = plan
  assert {
    condition = strcontains(
      module.gitops.application_repo_url,
      "gitea-http.gitea.svc.cluster.local"
    )
    error_message = "Application repo URL must point at the in-cluster Gitea service."
  }
}

run "argocd_application_tracks_greeter_branch" {
  command = plan
  variables {
    greeter_branch = "feature/demo-foo"
  }
  assert {
    condition     = output.argocd_target_revision == "feature/demo-foo"
    error_message = "ArgoCD targetRevision must equal greeter_branch."
  }
}

run "gitea_push_url_exposes_host_port" {
  command = plan
  assert {
    condition = strcontains(
      nonsensitive(output.gitea_push_url),
      "localhost:3000"
    )
    error_message = "gitea_push_url must expose localhost:3000 for host pushes."
  }
}

run "gitea_web_url_exposes_host_port" {
  command = plan
  assert {
    condition     = output.gitea_web_url == "http://localhost:3000"
    error_message = "gitea_web_url must point at the host-side Gitea UI."
  }
}

run "greeter_url_uses_default_host_port" {
  command = plan
  assert {
    condition     = output.greeter_url == "http://localhost:8081/"
    error_message = "greeter_url must use the default Traefik ingress port (8081)."
  }
}

run "argocd_port_forward_hint_uses_argocd_host_port" {
  command = plan
  assert {
    condition     = strcontains(output.argocd_port_forward_hint, "8080:80")
    error_message = "Port-forward hint must use the default argocd_host_port (8080)."
  }
}

run "rejects_empty_branch" {
  command = plan
  variables {
    greeter_branch = ""
  }
  expect_failures = [var.greeter_branch]
}
