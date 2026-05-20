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
  enable_cluster_creator_admin_permissions = false

  # Pin KMS admin to stable ARNs so the key policy doesn't drift based on who runs apply.
  kms_key_administrators = compact(concat(var.cluster_admin_arns, [var.ci_infra_role_arn]))

  access_entries = merge(
    length(aws_iam_role.cluster_admin) > 0 ? {
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
    } : {},
    length(aws_iam_role.console_admin) > 0 ? {
      console_admin = {
        kubernetes_groups = []
        principal_arn     = aws_iam_role.console_admin[0].arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {},
    var.ci_infra_role_arn != "" ? {
      ci_infra = {
        kubernetes_groups = []
        principal_arn     = var.ci_infra_role_arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {}
  )

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
    # Required for EKS Pod Identity associations to work - lightweight DaemonSet
    # that exchanges pod tokens for IAM credentials. Verify version via:
    # aws eks describe-addon-versions --addon-name eks-pod-identity-agent --kubernetes-version 1.35
    eks-pod-identity-agent = {
      addon_version = "v1.3.10-eksbuild.3"
    }
    # Deploys Fluent Bit + CloudWatch agent DaemonSets. Container stdout is
    # shipped to CloudWatch Logs; Container Insights metrics power the downtime
    # alarm. Access is granted via EKS Pod Identity (see aws_eks_pod_identity_association
    # below). See README "Observability".
    amazon-cloudwatch-observability = {
      addon_version = "v5.4.0-eksbuild.1"
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

# IAM role for the CloudWatch Observability add-on, accessed via EKS Pod Identity.
# Pod Identity (K8s 1.24+) grants permissions at pod scope rather than node scope.
resource "aws_iam_role" "cloudwatch_observability" {
  count = var.create ? 1 : 0
  name  = "${local.cluster_name}-cloudwatch-observability"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = module.label.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability" {
  count      = var.create ? 1 : 0
  role       = aws_iam_role.cloudwatch_observability[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Binds the IAM role to the cloudwatch-agent service account that the add-on
# creates in the amazon-cloudwatch namespace.
resource "aws_eks_pod_identity_association" "cloudwatch_observability" {
  count           = var.create ? 1 : 0
  cluster_name    = module.eks.cluster_name
  namespace       = "amazon-cloudwatch"
  service_account = "cloudwatch-agent"
  role_arn        = aws_iam_role.cloudwatch_observability[0].arn
}

# Application log group fed by the Fluent Bit DaemonSet (amazon-cloudwatch-observability
# add-on). The greeter writes JSON to stdout (log/slog) which Fluent Bit ships here.
# See README "Observability".
resource "aws_cloudwatch_log_group" "greeter" {
  count             = var.create ? 1 : 0
  name              = "/aws/eks/${local.cluster_name}/application/greeter"
  retention_in_days = 14
}

# Downtime alarm reads Container Insights metric pod_number_of_running_containers
# for the greeter namespace. Notification actions are intentionally unwired - the
# alarm definition itself is the showcase artifact; SNS wiring is documented in
# the README as the production path.
resource "aws_cloudwatch_metric_alarm" "greeter_downtime" {
  count               = var.create ? 1 : 0
  alarm_name          = "${module.label.id}-greeter-downtime"
  alarm_description   = "Greeter has <1 running container in namespace 'greeter' for 2 minutes. Wire SNS to enable notifications."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  namespace           = "ContainerInsights"
  metric_name         = "pod_number_of_running_containers"
  treat_missing_data  = "breaching"
  dimensions = {
    Namespace   = "greeter"
    ClusterName = local.cluster_name
  }
}

resource "aws_iam_role" "cluster_admin" {
  count = var.create && length(var.cluster_admin_arns) > 0 ? 1 : 0
  name  = "${local.cluster_name}-cluster-admin"

  # Allow both human admins (cluster_admin_arns) and CI (ci_infra_role_arn) to assume this role.
  # providers.tf uses --role-arn to get EKS tokens; both identities must be able to assume it.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = compact(concat(var.cluster_admin_arns, [var.ci_infra_role_arn])) }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = module.label.tags
}

resource "aws_iam_role_policy" "cluster_admin_eks_console" {
  count = var.create && length(var.cluster_admin_arns) > 0 ? 1 : 0
  name  = "eks-console-access-ro"
  role  = aws_iam_role.cluster_admin[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "eks:ListFargateProfiles",
        "eks:DescribeFargateProfile",
        "eks:ListAccessEntries",
        "eks:DescribeAccessEntry",
        "eks:ListAssociatedAccessPolicies",
        "eks:ListAddons",
        "eks:DescribeAddon",
        "eks:DescribeClusterVersions",
      ]
      Resource = "*"
    }]
  })
}

# Tradeoff: AmazonEC2ReadOnlyAccess is broad (all EC2 read, all resources).
# Required so the EKS console can show node instance details via EC2 APIs.
# In prod, narrow this to the specific EC2 describe actions needed for the cluster's VPC/nodes.
resource "aws_iam_role_policy_attachment" "cluster_admin_ec2_readonly" {
  count      = var.create && length(var.cluster_admin_arns) > 0 ? 1 : 0
  role       = aws_iam_role.cluster_admin[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role" "console_admin" {
  count = var.create && length(var.console_admin_arns) > 0 ? 1 : 0
  name  = "${local.cluster_name}-console-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.console_admin_arns }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = module.label.tags
}

resource "aws_iam_role_policy" "console_admin_eks_console" {
  count = var.create && length(var.console_admin_arns) > 0 ? 1 : 0
  name  = "eks-console-access-ro"
  role  = aws_iam_role.console_admin[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "eks:ListFargateProfiles",
        "eks:DescribeFargateProfile",
        "eks:ListAccessEntries",
        "eks:DescribeAccessEntry",
        "eks:ListAssociatedAccessPolicies",
        "eks:ListAddons",
        "eks:DescribeAddon",
        "eks:DescribeClusterVersions",
      ]
      Resource = "*"
    }]
  })
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
