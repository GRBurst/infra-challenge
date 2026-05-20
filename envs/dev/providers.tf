data "aws_caller_identity" "this" {}

locals {
  # Mirrors modules/platform local.cluster_name = "${namespace}-${environment}-eks".
  # Duplicated here because Terraform providers cannot reference module outputs.
  cluster_name      = "${var.namespace}-${var.environment}-eks"
  cluster_admin_arn = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${local.cluster_name}-cluster-admin"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      env        = var.environment
      managed_by = "opentofu"
      repo       = var.github_repo
    }
  }
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", local.cluster_name,
        "--region", var.region,
        "--role-arn", local.cluster_admin_arn,
      ]
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", local.cluster_name,
      "--region", var.region,
      "--role-arn", local.cluster_admin_arn,
    ]
  }
}
