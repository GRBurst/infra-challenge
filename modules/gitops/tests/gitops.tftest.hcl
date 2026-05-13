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
