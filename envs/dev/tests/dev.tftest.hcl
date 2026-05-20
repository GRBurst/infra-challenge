mock_provider "aws" {
  mock_data "aws_eks_cluster" {
    defaults = {
      endpoint = "https://mock.eks.endpoint"
      certificate_authority = [{
        data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCg=="
      }]
    }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}
mock_provider "tls" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}

# create_platform=false skips EKS/VPC resource creation so mock providers work.
# Tests still verify gitops wiring and local variable values.
variables {
  create_platform    = false
  cluster_admin_arns = []
  namespace          = "hm"
  environment        = "dev"
  region             = "eu-central-1"
  github_repo        = "GRBurst/infra-challenge"
}

run "providers_cluster_name_matches_formula" {
  command = plan
  override_module {
    target = module.bootstrap
    outputs = {
      s3_bucket_name      = "hm-dev-tofu-state-123456789012"
      dynamodb_table_name = "hm-dev-tofu-locks"
      ci_app_role_arn     = "arn:aws:iam::123456789012:role/hm-dev-ci-app-role"
      ci_infra_role_arn   = "arn:aws:iam::123456789012:role/hm-dev-github-oidc-role"
    }
  }
  assert {
    condition     = local.cluster_name == "hm-dev-eks"
    error_message = "providers.tf local.cluster_name must equal {namespace}-{environment}-eks."
  }
}

run "gitops_module_tracks_challenge_branch" {
  command = plan
  override_module {
    target = module.bootstrap
    outputs = {
      s3_bucket_name      = "hm-dev-tofu-state-123456789012"
      dynamodb_table_name = "hm-dev-tofu-locks"
      ci_app_role_arn     = "arn:aws:iam::123456789012:role/hm-dev-ci-app-role"
      ci_infra_role_arn   = "arn:aws:iam::123456789012:role/hm-dev-github-oidc-role"
    }
  }
  assert {
    condition     = module.gitops.application_target_revision == "challenge"
    error_message = "gitops module target_revision must be 'challenge' for dev (temporary; revert when merging to main)."
  }
}

run "gitops_module_uses_github_repo_url" {
  command = plan
  override_module {
    target = module.bootstrap
    outputs = {
      s3_bucket_name      = "hm-dev-tofu-state-123456789012"
      dynamodb_table_name = "hm-dev-tofu-locks"
      ci_app_role_arn     = "arn:aws:iam::123456789012:role/hm-dev-ci-app-role"
      ci_infra_role_arn   = "arn:aws:iam::123456789012:role/hm-dev-github-oidc-role"
    }
  }
  assert {
    condition     = module.gitops.application_repo_url == "https://github.com/GRBurst/infra-challenge.git"
    error_message = "gitops module must point at the GitHub repo URL."
  }
}

run "ecr_url_is_exported" {
  command = plan
  override_module {
    target = module.bootstrap
    outputs = {
      s3_bucket_name      = "hm-dev-tofu-state-123456789012"
      dynamodb_table_name = "hm-dev-tofu-locks"
      ci_app_role_arn     = "arn:aws:iam::123456789012:role/hm-dev-ci-app-role"
      ci_infra_role_arn   = "arn:aws:iam::123456789012:role/hm-dev-github-oidc-role"
    }
  }
  assert {
    condition     = output.ecr_repository_url != null
    error_message = "ecr_repository_url must be a top-level output."
  }
}

run "ecr_registry_host_is_exported" {
  command = plan
  override_module {
    target = module.bootstrap
    outputs = {
      s3_bucket_name      = "hm-dev-tofu-state-123456789012"
      dynamodb_table_name = "hm-dev-tofu-locks"
      ci_app_role_arn     = "arn:aws:iam::123456789012:role/hm-dev-ci-app-role"
      ci_infra_role_arn   = "arn:aws:iam::123456789012:role/hm-dev-github-oidc-role"
    }
  }
  assert {
    condition     = output.ecr_registry_host != null
    error_message = "ecr_registry_host must be a top-level output for CI docker login."
  }
}

run "cluster_name_is_exported" {
  command = plan
  override_module {
    target = module.bootstrap
    outputs = {
      s3_bucket_name      = "hm-dev-tofu-state-123456789012"
      dynamodb_table_name = "hm-dev-tofu-locks"
      ci_app_role_arn     = "arn:aws:iam::123456789012:role/hm-dev-ci-app-role"
      ci_infra_role_arn   = "arn:aws:iam::123456789012:role/hm-dev-github-oidc-role"
    }
  }
  assert {
    condition     = output.cluster_name != null
    error_message = "cluster_name must be a top-level output (derives from local.cluster_name = hm-dev-eks)."
  }
}

run "cluster_admin_arns_flows_to_platform" {
  command = plan
  variables {
    cluster_admin_arns = ["arn:aws:iam::111111111111:user/reviewer"]
  }
  override_module {
    target = module.bootstrap
    outputs = {
      s3_bucket_name      = "hm-dev-tofu-state-123456789012"
      dynamodb_table_name = "hm-dev-tofu-locks"
      ci_app_role_arn     = "arn:aws:iam::123456789012:role/hm-dev-ci-app-role"
      ci_infra_role_arn   = "arn:aws:iam::123456789012:role/hm-dev-github-oidc-role"
    }
  }
  assert {
    condition = contains(
      module.platform.cluster_admin_arns,
      "arn:aws:iam::111111111111:user/reviewer"
    )
    error_message = "envs/dev must surface cluster_admin_arns as an input variable."
  }
}
