locals {
  # Must match modules/platform local.cluster_name = "${namespace}-${environment}-eks".
  # Duplicated here because Terraform providers cannot reference module outputs.
  cluster_name = "hm-dev-eks"
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      env        = "dev"
      managed_by = "opentofu"
      repo       = "GRBurst/infra-challenge"
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
        "--region", "eu-central-1",
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
      "--region", "eu-central-1",
    ]
  }
}
