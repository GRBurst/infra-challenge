mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  environment = "local"
}

run "argocd_installed_into_argocd_namespace" {
  command = plan
  assert {
    condition     = helm_release.argocd.namespace == "argocd"
    error_message = "ArgoCD must be installed into the 'argocd' namespace."
  }
}

run "application_points_at_local_values_file" {
  command = plan
  assert {
    condition = strcontains(
      jsonencode(kubernetes_manifest.application.manifest),
      "values-local.yaml"
    )
    error_message = "Application CR must reference values-local.yaml when environment=local."
  }
}

run "appproject_restricts_to_greeter_namespace" {
  command = plan
  assert {
    condition     = length(kubernetes_manifest.appproject.manifest.spec.destinations) == 1
    error_message = "AppProject must whitelist exactly one destination."
  }
}

run "invalid_environment_rejected" {
  command = plan
  variables {
    environment = "staging"
  }
  expect_failures = [var.environment]
}

run "custom_repo_url_flows_to_application_and_appproject" {
  command = plan
  variables {
    environment      = "local"
    greeter_repo_url = "http://gitea-http.gitea.svc.cluster.local:3000/gitea-admin/infra-challenge.git"
  }
  assert {
    condition = strcontains(
      jsonencode(kubernetes_manifest.application.manifest),
      "gitea-http.gitea.svc.cluster.local"
    )
    error_message = "Application.spec.source.repoURL must use override."
  }
  assert {
    condition = strcontains(
      jsonencode(kubernetes_manifest.appproject.manifest),
      "gitea-http.gitea.svc.cluster.local"
    )
    error_message = "AppProject.spec.sourceRepos must use override."
  }
}

run "appproject_permits_namespace_for_create_namespace_sync_option" {
  command = plan
  assert {
    condition = anytrue([
      for r in kubernetes_manifest.appproject.manifest.spec.clusterResourceWhitelist :
      r.group == "" && r.kind == "Namespace"
    ])
    error_message = "AppProject.clusterResourceWhitelist must include Namespace so CreateNamespace=true can create the greeter namespace at PreSync."
  }
}

run "custom_target_revision_flows_to_application" {
  command = plan
  variables {
    environment             = "local"
    greeter_target_revision = "feature/demo-x"
  }
  assert {
    condition = strcontains(
      jsonencode(kubernetes_manifest.application.manifest),
      "feature/demo-x"
    )
    error_message = "Application.spec.source.targetRevision must reflect override."
  }
}
