# AWS & OpenTofu: Core Infrastructure Rules

This document provides a concise, actionable set of rules for managing Amazon
Web Services (AWS) infrastructure with OpenTofu.

Role: Expert infrastructure architect and devops engineer. Prioritize
maintainability, safety, human-readable code, and small correct changes.

## 0. Meta Information

- This is a project running on nix flake and direnv. If you need to run a
  command, you usually already have the correct environment and can run
  `<mycommand>`. If you see this failing because of missing tools or similar,
  run `direnv exec . <mycommand>`. Otherwise, reload the environment for the
  current terminal session with `direnv reload`.
- Commands are usually run in `zsh`.
- GitHub is used for ci/cd.
- OpenTofu (cmd `tofu`) is used for infrastructure deployment to AWS.
- Helm charts managed by OpenTofu can be used for setting up EKS for the app
  deployment.
- DO run intermediate checks for formatting, linting, validation, security
  scanning, and planning at the end of every change or step by using the `just`
  recipes from the repository root when available.

## 1. Project Structure & Naming

- DO use a standard project layout. We have on top level:
  - `/modules`: For all reusable infrastructure components.
  - `/envs`: For environment-specific configuration and separation (e.g. local,
    staging, prod).
- DO In the modules (module folders) and envs, follow best practices for file
  structures:
  - `main.tf`: Root module resource definitions.
  - `variables.tf`: Root module variable declarations.
  - `outputs.tf`: Root module output declarations.
  - `versions.tf`: OpenTofu and provider version constraints.
- DO Embed Cloud Posse null-label everywhere, in each module and in the root
  module for a uniform naming.
- DO use declarative blocks like moved, deleted and import for resources and
  state management.
- DO Reference names of resources as much as possible, instead of constructing
  the name multiple times. This is much more robust.
- DON'T place non-essential files (like documentation or helper scripts) in the
  root directory. Use `/docs` and `/scripts` respectively.

## 2. State & Dependencies

- DO use a Google Cloud Storage (GCS) bucket as the remote backend for state
  files. Enable object versioning on the bucket to prevent data loss, for
  example:
  ```tofu
  terraform {
    backend "s3" {
      bucket  = "my-project-tf-state-bucket"
      prefix  = "infra/state"
    }
  }
  ```
- DON'T ever store state files locally for collaborative projects.
- DO pin module versions in `versions.tf` by referencing a specific Git tag or
  commit hash to ensure repeatable builds.

## 3. Security & IAM

- DON'T hardcode secrets (API keys, credentials) in your code. Use Google Secret
  Manager and reference secrets via data sources.
- DO follow the principle of least privilege. Grant service accounts only the
  specific IAM roles they need to function.
- DO prefer fine-grained IAM resources over broader ones to avoid accidental
  privilege escalation.
- DO use OpenId Connect for authenticating external workloads to AWS instead of
  exporting service account keys.
- DON'T create public S3 buckets by default. Enforce private access and use
  uniform bucket-level access control.
- DO configure firewall rules to deny all traffic by default and only allow
  necessary ingress/egress. Protect public endpoints with Google Cloud Armor.
- DO IMPORTANT: Use Worload Identity Federation and related concepts whenever
  possible.
- DO strongly prefer Terraform 1.10 Ephemeral Resources like
  `ephemeral "random_password"`.
- DO strongly prefer Terraform 1.11 Write-Only Arguments like `data_wo` in
  `kubernetes_secret_v1`.

## 4. Code Quality & Patterns

- DO use declarative tooling ant stick to it. We have the repository centered
  around declarative tools, most importantly `nix`, OpenTofu (`tofu`).
- DON'T hardcode values like project IDs, regions, or instance sizes.
  Parameterize everything with variables and provide sensible defaults.
- DO use `for_each` when creating multiple similar resources. It creates a more
  stable and predictable resource lifecycle than `count`.
- DON'T make manual changes to infrastructure managed by OpenTofu. This leads to
  state drift and unexpected errors.
- DO create small, focused, and reusable modules for repeated patterns (e.g., a
  load balancer with a managed instance group). Avoid monolithic modules.
- DO label all AWS resources for cost tracking, ownership, and automation. Pass
  labels as a map variable.
- DO avoid manual setup step with kubectl, gcloud or similar. Use terraforms
  `null` resource with local-exec provisioner instead.
- DO strongly prefer latest versioned resources like
  `kubernetes_horizontal_pod_autoscaler_v2` instead of
  `kubernetes_horizontal_pod_autoscaler_v1` or
  `kubernetes_horizontal_pod_autoscaler`.
- DO use and introduce stable identifiers whenever resources get referenced.
  Therefore, prefer service names or local dns over ip address, introduce stable
  node tags instead of gcp generated ones etc.
- DO use and declarative instructions instead of cli whenever possible. This
  includes `import` and `moved` blocks for example, but should be considered a
  general best practice pattern.

### Test-Driven Development (TDD)

Strict Red-Green-Refactor cycle required. AGENT RULE: When adding a feature or
fixing a bug, you MUST output failing test code before outputting implementation
code.

## 5. Tooling & Automation

- DO use the `justfile` as the primary command interface for local checks and
  automation. Run these commands from the repository root unless a recipe is
  intentionally directory-local:
  - `just check`: Run the standard CI-equivalent local checks.
  - `just fix`: Apply all auto-fixable formatting and lint changes.
  - `just fmt-check`: Verify formatting.
  - `just validate`: Check configuration validity for all environments.
  - `just tflint`: Lint for best practices and potential errors.
  - `just security`: Run the Trivy IaC security scan.
  - `just`: List the full set of available recipes.
  - `just plan`: Plan infrastructure change (tofu plan) from the current
    environment.
- DO use the environment-local `just` workflows for planning and apply-style
  operations. For example, from an environment directory use `just plan` instead
  of calling `tofu plan` directly.
- DO automate everything. Your CI pipeline should cover the same formatting,
  linting, validation, and security workflows exposed through `just`, and run an
  environment-specific `just plan` on every pull request.
- DO use a testing framework like Terratest for integration testing of complex
  modules.
- DO write scripts that are compatible on nixos.
- DO write code that is suitable to be deployed via CI, therefore prefer
  terraform solutions as much as possible and do not use untracked
  `*.auto.tfvars` or similar approaches that only work locally.
- NEVER apply (`tofu apply`) changes yourself or commit changes yourself.

## Summary Creation And Learnings

Whenever code or repo instructions are changed, write a concise markdown summary
in the project root. If follow ups are required, add them explicitly in the
summary. When a durable repo-specific lesson would help future work, add it to
this file instead of keeping it implicit.
