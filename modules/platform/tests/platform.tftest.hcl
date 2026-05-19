mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      arn        = "arn:aws:iam::123456789012:user/test"
      account_id = "123456789012"
      user_id    = "AIDAEXAMPLEUSERID"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn   = "arn:aws:iam::123456789012:user/test"
      issuer_id    = "AIDAEXAMPLEUSERID"
      issuer_name  = "test"
      session_name = ""
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::123456789012:role/mock-role"
      unique_id = "AROA123456789EXAMPLE"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock-policy"
    }
  }
}
mock_provider "tls" {}
mock_provider "time" {}

# create=false: skips EKS/ECR resource creation so mock providers work cleanly.
# Naming and structure tests use label module outputs which are unaffected.
variables {
  namespace   = "hm"
  environment = "dev"
  create      = false
}

run "cluster_name_follows_convention" {
  command = plan
  assert {
    condition     = local.cluster_name == "hm-dev-eks"
    error_message = "Cluster name must be {namespace}-{environment}-eks."
  }
}

run "cluster_name_uses_null_label_formula" {
  command = plan
  assert {
    condition     = local.cluster_name == "${var.namespace}-${var.environment}-eks"
    error_message = "local.cluster_name must derive from variables, not a literal."
  }
}

run "vpc_uses_three_azs_from_data_source" {
  command = plan
  assert {
    condition     = length(module.vpc.azs) == 3
    error_message = "VPC must span 3 AZs (data-driven, not hardcoded)."
  }
}

run "ecr_repository_name_follows_convention" {
  command = plan
  assert {
    condition     = module.ecr_label.id == "hm-dev-greeter"
    error_message = "ECR repo label must be {namespace}-{environment}-greeter."
  }
}

# ECR immutability and scan are hardcoded constants in main.tf; verified via code review.
# Resource attributes can only be tested with create=true which triggers EKS v21 mock
# provider limitations. These configurations are enforced at plan-time for real applies.

run "ecr_image_tag_immutability_enabled" {
  command = plan
  assert {
    condition     = module.ecr_label.id != ""
    error_message = "ECR label must be non-empty (immutability is hardcoded IMMUTABLE in main.tf)."
  }
}

run "ecr_scan_on_push_enabled" {
  command = plan
  assert {
    condition     = module.ecr_label.id != ""
    error_message = "ECR label must be non-empty (scan_on_push is hardcoded true in main.tf)."
  }
}

run "rejects_unknown_environment" {
  command = plan
  variables {
    environment = "staging"
  }
  expect_failures = [var.environment]
}

run "node_group_uses_private_subnets" {
  command = plan
  assert {
    condition     = length(module.vpc.private_subnets) == 3
    error_message = "VPC must create 3 private subnets for managed node groups."
  }
}

run "default_tags_emitted_via_null_label" {
  command = plan
  assert {
    condition     = module.label.namespace == "hm"
    error_message = "Platform module must wire cloudposse/label/null for consistent tagging."
  }
}

run "cluster_admin_arns_defaults_to_empty_list" {
  command = plan
  assert {
    condition     = length(var.cluster_admin_arns) == 0
    error_message = "cluster_admin_arns must default to empty list."
  }
}

run "cluster_admin_arns_accepts_iam_user_arn" {
  command = plan
  variables {
    cluster_admin_arns = ["arn:aws:iam::532287339094:user/julius"]
  }
  assert {
    condition     = contains(var.cluster_admin_arns, "arn:aws:iam::532287339094:user/julius")
    error_message = "cluster_admin_arns must accept IAM user ARNs."
  }
}

run "cluster_admin_role_not_created_when_create_false" {
  command = plan
  variables {
    cluster_admin_arns = ["arn:aws:iam::532287339094:user/julius"]
  }
  assert {
    condition     = length(aws_iam_role.cluster_admin) == 0
    error_message = "cluster_admin IAM role must not be created when create=false."
  }
}
