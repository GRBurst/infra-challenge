provider "aws" {
  region = "eu-central-1"
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  namespace   = "hm" # Replace with your company name
  environment = "dev"
  github_repo = "GRBurst/infra-challenge"
}
