terraform {
  backend "s3" {
    bucket         = "hm-dev-tofu-state-532287339094"
    key            = "bootstrap/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "hm-dev-tofu-locks"
    encrypt        = true
  }
}
