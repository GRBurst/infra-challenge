provider "aws" {
  region = "eu-central-1"
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  namespace   = "hm"
  environment = "dev"
  github_repo = "GRBurst/infra-challenge"
}
