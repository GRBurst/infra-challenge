module "bootstrap" {
  source = "../../modules/bootstrap"

  namespace   = "hm"
  environment = "dev"
  github_repo = "GRBurst/infra-challenge"
}

module "platform" {
  source = "../../modules/platform"

  namespace   = "hm"
  environment = "dev"
  create      = var.create_platform
}

module "gitops" {
  source = "../../modules/gitops"

  environment     = "dev"
  repo_url        = "https://github.com/GRBurst/infra-challenge.git"
  target_revision = "main"

  depends_on = [module.platform]
}
