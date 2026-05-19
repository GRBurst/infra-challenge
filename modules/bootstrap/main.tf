data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Base label for the module
module "label" {
  source      = "cloudposse/label/null"
  version     = "0.25.0"
  namespace   = var.namespace
  environment = var.environment
}

# ------------------------------------------------------
# 1. S3 Bucket for Remote State
# ------------------------------------------------------
module "s3_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = module.label.context
  name    = "tofu-state"
}

resource "aws_s3_bucket" "state" {
  # Appending account ID to ensure global uniqueness. Optional
  bucket = "${module.s3_label.id}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ------------------------------------------------------
# 2. DynamoDB Table for State Locking
# ------------------------------------------------------
module "dynamo_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = module.label.context
  name    = "tofu-locks"
}

resource "aws_dynamodb_table" "locks" {
  name         = module.dynamo_label.id
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ------------------------------------------------------
# 3. Keyless Authentication via OIDC
# ------------------------------------------------------
module "oidc_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = module.label.context
  name    = "github-oidc-role"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

moved {
  from = aws_iam_role.ci_role
  to   = aws_iam_role.ci_infra_role
}

moved {
  from = aws_iam_role_policy_attachment.ci_admin
  to   = aws_iam_role_policy_attachment.ci_infra_admin
}

resource "aws_iam_role" "ci_infra_role" {
  name = module.oidc_label.id

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/challenge"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ci_infra_admin" {
  role       = aws_iam_role.ci_infra_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

module "ci_app_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = module.label.context
  name    = "ci-app-role"
}

resource "aws_iam_role" "ci_app_role" {
  name = module.ci_app_label.id

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:${var.environment}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ci_app_ecr" {
  name = "ecr-push"
  role = aws_iam_role.ci_app_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeImages",
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.namespace}-${var.environment}-greeter"
      },
    ]
  })
}
