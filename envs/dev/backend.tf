terraform {
  # Backend blocks cannot interpolate variables. The literal bucket, region, and
  # dynamodb_table here MUST stay in sync with namespace/environment/region in
  # terraform.tfvars and with the resources the bootstrap module creates.
  backend "s3" {
    bucket         = "hm-dev-tofu-state-532287339094"
    key            = "bootstrap/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "hm-dev-tofu-locks"
    encrypt        = true
  }
}
