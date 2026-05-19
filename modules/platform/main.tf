module "label" {
  source      = "cloudposse/label/null"
  version     = "0.25.0"
  namespace   = var.namespace
  environment = var.environment
}

module "cluster_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = module.label.context
  name    = "eks"
}

module "vpc_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = module.label.context
  name    = "vpc"
}

module "ecr_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = module.label.context
  name    = "greeter"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = module.cluster_label.id
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = module.vpc_label.id
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  tags = module.label.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.20.0"

  create = var.create

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Dev tradeoff: public endpoint reachable, narrowable via CIDRs.
  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  access_entries = length(aws_iam_role.cluster_admin) > 0 ? {
    cluster_admin = {
      kubernetes_groups = []
      principal_arn     = aws_iam_role.cluster_admin[0].arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  } : {}

  addons = {
    # Versions verified at plan-authoring time via aws eks describe-addon-versions --kubernetes-version 1.35.
    coredns = {
      addon_version = "v1.14.2-eksbuild.4"
    }
    kube-proxy = {
      addon_version = "v1.35.3-eksbuild.5"
    }
    vpc-cni = {
      addon_version = "v1.21.1-eksbuild.8"
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_group_min_size
      max_size       = var.node_group_max_size
      desired_size   = var.node_group_desired_size
      subnet_ids     = module.vpc.private_subnets
    }
  }

  tags = module.label.tags
}

resource "aws_iam_role" "cluster_admin" {
  count = var.create && length(var.cluster_admin_arns) > 0 ? 1 : 0
  name  = "${local.cluster_name}-cluster-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.cluster_admin_arns }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = module.label.tags
}

resource "aws_ecr_repository" "greeter" {
  count                = var.create ? 1 : 0
  name                 = module.ecr_label.id
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = module.label.tags
}

resource "aws_ecr_lifecycle_policy" "greeter" {
  count      = var.create ? 1 : 0
  repository = aws_ecr_repository.greeter[0].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}
