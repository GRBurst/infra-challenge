mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      arn        = "arn:aws:iam::123456789012:user/test"
      account_id = "123456789012"
      user_id    = "AIDAEXAMPLEUSERID"
    }
  }
  mock_data "aws_region" {
    defaults = {
      name = "eu-central-1"
    }
  }
}
mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [{
        sha1_fingerprint     = "0000000000000000000000000000000000000000"
        cert_pem             = "mock-cert"
        is_ca                = false
        issuer               = "mock-issuer"
        not_after            = "2030-01-01T00:00:00Z"
        not_before           = "2020-01-01T00:00:00Z"
        public_key_algorithm = "RSA"
        serial_number        = "0"
        set_subject_key_id   = "mock-ski"
        signature_algorithm  = "SHA256-RSA"
        subject              = "mock-subject"
        max_path_length      = -1
        version              = 3
      }]
    }
  }
}

variables {
  namespace   = "hm"
  environment = "dev"
  github_repo = "GRBurst/infra-challenge"
}

run "ci_infra_role_oidc_sub_is_tightened" {
  command = plan
  assert {
    condition = strcontains(
      aws_iam_role.ci_infra_role.assume_role_policy,
      "repo:GRBurst/infra-challenge:ref:refs/heads/challenge"
    )
    error_message = "ci_infra_role OIDC sub must be scoped to challenge branch only."
  }
}

run "ci_infra_role_oidc_sub_rejects_wildcard" {
  command = plan
  assert {
    condition = !strcontains(
      aws_iam_role.ci_infra_role.assume_role_policy,
      "repo:GRBurst/infra-challenge:ref:refs/heads/main"
    )
    error_message = "ci_infra_role must not accept main branch (currently swapped to challenge)."
  }
}

run "ci_app_role_exists" {
  command = plan
  assert {
    condition     = aws_iam_role.ci_app_role.name != ""
    error_message = "ci_app_role must be defined."
  }
}

run "ci_app_role_oidc_sub_scoped_to_environment" {
  command = plan
  assert {
    condition = strcontains(
      aws_iam_role.ci_app_role.assume_role_policy,
      "repo:GRBurst/infra-challenge:environment:dev"
    )
    error_message = "ci_app_role OIDC sub must be scoped to GitHub Environment 'dev', per docs/multi-account.md."
  }
}

run "ci_app_role_has_ecr_policy" {
  command = plan
  assert {
    condition = strcontains(
      aws_iam_role_policy.ci_app_ecr.policy,
      "ecr:PutImage"
    )
    error_message = "ci_app_role must grant ecr:PutImage."
  }
}

run "ci_app_role_ecr_arn_scoped_to_current_account_and_region" {
  command = plan
  assert {
    condition = !strcontains(
      aws_iam_role_policy.ci_app_ecr.policy,
      "arn:aws:ecr:eu-central-1:*:repository"
    )
    error_message = "ECR resource ARN must not use wildcard account."
  }
  assert {
    condition = strcontains(
      aws_iam_role_policy.ci_app_ecr.policy,
      "repository/hm-dev-greeter"
    )
    error_message = "ci_app_role ECR resource must scope to hm-dev-greeter repo."
  }
}
