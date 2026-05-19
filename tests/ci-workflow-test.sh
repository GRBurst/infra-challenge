#!/usr/bin/env bash
# Structural contract test for .github/workflows/ci.yml.
# Asserts the workflow shape: required jobs, dependencies, OIDC permissions,
# environment scoping, role variable plumbing, and two-phase apply commands.
# Pure static analysis via yq — no AWS, no GitHub, no network.
#
# Run via: nix develop --command bash tests/ci-workflow-test.sh
set -euo pipefail

WF=".github/workflows/ci.yml"
fail=0

expect() {
  local name="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    fail=1
  fi
}

# --- deploy-platform job ---
expect "deploy-platform job exists" \
  "yq -e '.jobs.\"deploy-platform\"' $WF"
expect "deploy-platform gated to main" \
  "yq -e '.jobs.\"deploy-platform\".if | test(\"refs/heads/main\")' $WF"
expect "deploy-platform has id-token write" \
  "yq -e '.jobs.\"deploy-platform\".permissions.\"id-token\" == \"write\"' $WF"
expect "deploy-platform uses dev environment" \
  "yq -e '.jobs.\"deploy-platform\".environment == \"dev\"' $WF"
expect "deploy-platform reads CI_INFRA_ROLE_ARN var" \
  "yq -e '.jobs.\"deploy-platform\".env | to_entries[] | select(.value | test(\"CI_INFRA_ROLE_ARN\"))' $WF"
expect "deploy-platform calls tofu apply with -target=module.bootstrap" \
  "yq -e '.jobs.\"deploy-platform\".steps[].run | select(. != null) | test(\"-target=module.bootstrap\")' $WF"
expect "deploy-platform calls tofu apply with -target=module.platform" \
  "yq -e '.jobs.\"deploy-platform\".steps[].run | select(. != null) | test(\"-target=module.platform\")' $WF"

# --- deploy-gitops job ---
expect "deploy-gitops job exists" \
  "yq -e '.jobs.\"deploy-gitops\"' $WF"
expect "deploy-gitops needs deploy-platform" \
  "yq -e '.jobs.\"deploy-gitops\".needs | test(\"deploy-platform\")' $WF"
expect "deploy-gitops gated to main" \
  "yq -e '.jobs.\"deploy-gitops\".if | test(\"refs/heads/main\")' $WF"
expect "deploy-gitops has id-token write" \
  "yq -e '.jobs.\"deploy-gitops\".permissions.\"id-token\" == \"write\"' $WF"
expect "deploy-gitops uses dev environment" \
  "yq -e '.jobs.\"deploy-gitops\".environment == \"dev\"' $WF"
expect "deploy-gitops reads CI_INFRA_ROLE_ARN var" \
  "yq -e '.jobs.\"deploy-gitops\".env | to_entries[] | select(.value | test(\"CI_INFRA_ROLE_ARN\"))' $WF"
expect "deploy-gitops calls tofu apply" \
  "yq -e '[.jobs.\"deploy-gitops\".steps[].run | select(. == \"*tofu apply*\")] | length > 0' $WF"
expect "deploy-gitops tofu apply has no -target flag" \
  "[ \"\$(yq '[.jobs.\"deploy-gitops\".steps[].run | select(. == \"*tofu apply*\") | select(. == \"*-target*\")] | length' $WF)\" = \"0\" ]"

# --- regression guards on existing jobs ---
expect "check job still exists" \
  "yq -e '.jobs.check' $WF"
expect "build-and-push still gated to main" \
  "yq -e '.jobs.\"build-and-push\".if | test(\"refs/heads/main\")' $WF"
expect "build-and-push still needs check" \
  "yq -e '.jobs.\"build-and-push\".needs | test(\"check\")' $WF"

[ "$fail" -eq 0 ] || exit 1
echo "All structural assertions passed."
