module "gitea" {
  source = "../../modules/gitea"

  chart_version = var.gitea_chart_version
}

module "gitops" {
  source = "../../modules/gitops"

  environment     = "local"
  repo_url        = module.gitea.repo_url
  target_revision = var.greeter_branch
  create_apps     = var.create_apps

  depends_on = [module.gitea]
}
