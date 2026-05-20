module "bootstrap" {
  source = "../../modules/bootstrap"

  namespace   = var.namespace
  environment = "dev"
  github_repo = var.github_repo
}

module "platform" {
  source = "../../modules/platform"

  namespace          = var.namespace
  environment        = "dev"
  create             = var.create_platform
  cluster_admin_arns = var.cluster_admin_arns
  console_admin_arns = var.console_admin_arns
  ci_infra_role_arn  = module.bootstrap.ci_infra_role_arn
}

module "gitops" {
  source = "../../modules/gitops"

  environment     = "dev"
  repo_url        = "https://github.com/${var.github_repo}.git"
  target_revision = var.target_revision

  depends_on = [module.platform]
}
