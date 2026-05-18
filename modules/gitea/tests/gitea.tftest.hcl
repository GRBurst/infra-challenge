mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  chart_version = "11.0.1"
}

run "namespace_uses_default_gitea" {
  command = plan
  assert {
    condition     = kubernetes_namespace_v1.gitea.metadata[0].name == "gitea"
    error_message = "Default namespace must be 'gitea'."
  }
}

run "namespace_override_flows_through" {
  command = plan
  variables {
    namespace = "gitea-test"
  }
  assert {
    condition     = kubernetes_namespace_v1.gitea.metadata[0].name == "gitea-test"
    error_message = "Namespace variable must override the default."
  }
}

run "helm_release_deploys_pinned_gitea_chart" {
  command = plan
  assert {
    condition     = helm_release.gitea.chart == "gitea"
    error_message = "Must deploy upstream gitea chart."
  }
  assert {
    condition     = helm_release.gitea.repository == "https://dl.gitea.com/charts/"
    error_message = "Must use upstream Gitea Helm repository."
  }
  assert {
    condition     = helm_release.gitea.version == "11.0.1"
    error_message = "Chart version must be pinned via variable (no floating)."
  }
}

run "helm_release_in_module_namespace" {
  command = plan
  assert {
    condition     = helm_release.gitea.namespace == "gitea"
    error_message = "Helm release must be deployed into the managed namespace."
  }
}

run "repo_url_targets_cluster_internal_service" {
  command = plan
  assert {
    condition     = output.repo_url == "http://gitea-http.gitea.svc.cluster.local:3000/gitea-admin/infra-challenge.git"
    error_message = "repo_url must point at the in-cluster gitea-http service."
  }
}

run "push_url_uses_host_port_and_credentials" {
  command = plan
  assert {
    condition     = output.push_url == "http://gitea-admin:gitea-admin@localhost:3000/gitea-admin/infra-challenge.git"
    error_message = "push_url must include creds and host-side port."
  }
}

run "web_url_uses_host_port" {
  command = plan
  assert {
    condition     = output.web_url == "http://localhost:3000"
    error_message = "web_url must expose the host-side port for browser access."
  }
}

run "namespace_output_matches_namespace" {
  command = plan
  variables {
    namespace = "gitea-x"
  }
  assert {
    condition     = output.namespace == "gitea-x"
    error_message = "namespace output must reflect the actually-created namespace."
  }
}
