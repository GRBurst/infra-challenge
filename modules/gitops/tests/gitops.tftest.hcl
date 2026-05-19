mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  environment = "local"
  repo_url    = "https://github.com/GRBurst/infra-challenge.git"
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

run "uses_repo_url_input_verbatim" {
  command = plan
  variables {
    repo_url = "http://gitea-http.gitea.svc.cluster.local:3000/gitea-admin/infra-challenge.git"
  }
  assert {
    condition     = kubernetes_manifest.application.manifest.spec.source.repoURL == "http://gitea-http.gitea.svc.cluster.local:3000/gitea-admin/infra-challenge.git"
    error_message = "Application.spec.source.repoURL must equal repo_url input verbatim."
  }
  assert {
    condition     = kubernetes_manifest.appproject.manifest.spec.sourceRepos[0] == "http://gitea-http.gitea.svc.cluster.local:3000/gitea-admin/infra-challenge.git"
    error_message = "AppProject.spec.sourceRepos must restrict to repo_url input verbatim."
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
    target_revision = "feature/demo-x"
  }
  assert {
    condition     = kubernetes_manifest.application.manifest.spec.source.targetRevision == "feature/demo-x"
    error_message = "Application.spec.source.targetRevision must reflect target_revision input."
  }
}

run "hello_tag_uses_full_revision_for_local" {
  command = plan
  variables {
    environment     = "local"
    repo_url        = "http://gitea-http.gitea.svc.cluster.local:3000/x/y.git"
    target_revision = "main"
  }
  assert {
    condition = anytrue([
      for p in kubernetes_manifest.application.manifest.spec.source.helm.parameters :
      p.name == "helloTag" && p.value == "$ARGOCD_APP_REVISION"
    ])
    error_message = "For local env, Application must inject helloTag=$ARGOCD_APP_REVISION (full SHA)."
  }
}

run "hello_tag_parameter_omitted_for_dev" {
  command = plan
  variables {
    environment     = "dev"
    repo_url        = "https://github.com/GRBurst/infra-challenge.git"
    target_revision = "main"
  }
  assert {
    condition     = length(kubernetes_manifest.application.manifest.spec.source.helm.parameters) == 0
    error_message = "For dev env, Helm parameters must be empty so values-dev.yaml is the single source of truth for helloTag."
  }
}
