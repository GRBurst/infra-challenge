locals {
  gitea_namespace  = "gitea"
  gitea_admin_user = "gitea-admin"
  gitea_repo_name  = "infra-challenge"

  github_repo_url = "https://github.com/GRBurst/infra-challenge.git"
  gitea_svc_url   = "http://gitea-http.${local.gitea_namespace}.svc.cluster.local:3000/${local.gitea_admin_user}/${local.gitea_repo_name}.git"
  gitea_host_url  = "http://localhost:3000/${local.gitea_admin_user}/${local.gitea_repo_name}.git"

  greeter_repo_url   = var.gitea_enabled ? local.gitea_svc_url : local.github_repo_url
  greeter_target_rev = var.gitea_enabled ? var.greeter_branch : "HEAD"
}

resource "terraform_data" "validate_gitea_inputs" {
  lifecycle {
    precondition {
      condition     = !var.gitea_enabled || length(var.greeter_branch) > 0
      error_message = "greeter_branch must be a non-empty branch name when gitea_enabled=true."
    }
  }
  input = "validated"
}

resource "helm_release" "gitea" {
  count = var.gitea_enabled ? 1 : 0

  name             = "gitea"
  repository       = "https://dl.gitea.com/charts/"
  chart            = "gitea"
  version          = "11.0.1"
  namespace        = local.gitea_namespace
  create_namespace = true
  timeout          = 300

  values     = [file("${path.module}/../../local/gitea-values.yaml")]
  depends_on = [terraform_data.validate_gitea_inputs]
}

module "gitops" {
  source                  = "../../modules/gitops"
  environment             = "local"
  greeter_repo_url        = local.greeter_repo_url
  greeter_target_revision = local.greeter_target_rev

  depends_on = [helm_release.gitea]
}
