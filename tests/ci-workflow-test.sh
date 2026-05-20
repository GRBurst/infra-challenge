#!/usr/bin/env bash
# Structural contract test for .github/workflows/ci.yml.
# Asserts the workflow shape: required jobs, dependencies, OIDC permissions,
# environment scoping, role variable plumbing, and two-phase apply commands.
# Pure static analysis via yq - no AWS, no GitHub, no network.
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
expect "deploy-platform gated to challenge" \
  "yq -e '.jobs.\"deploy-platform\".if | test(\"refs/heads/challenge\")' $WF"
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
expect "deploy-gitops gated to challenge" \
  "yq -e '.jobs.\"deploy-gitops\".if | test(\"refs/heads/challenge\")' $WF"
expect "deploy-gitops has id-token write" \
  "yq -e '.jobs.\"deploy-gitops\".permissions.\"id-token\" == \"write\"' $WF"
expect "deploy-gitops uses dev environment" \
  "yq -e '.jobs.\"deploy-gitops\".environment == \"dev\"' $WF"
expect "deploy-gitops reads CI_INFRA_ROLE_ARN var" \
  "yq -e '.jobs.\"deploy-gitops\".env | to_entries[] | select(.value | test(\"CI_INFRA_ROLE_ARN\"))' $WF"
expect "deploy-gitops calls tofu apply" \
  "yq -e '[.jobs.\"deploy-gitops\".steps[].run | select(. == \"*tofu apply*\")] | length > 0' $WF"

# --- deploy-gitops two-phase apply ---

expect "deploy-gitops phase 2a targets module.gitops.helm_release.argocd" \
  "yq -e '
     [ .jobs.\"deploy-gitops\".steps[].run
       | select(. != null)
       | select(test(\"tofu apply\"))
       | select(test(\"-target=module.gitops.helm_release.argocd\")) ]
     | length == 1
   ' $WF"

expect "deploy-gitops phase 2b is an untargeted full apply" \
  "yq -e '
     [ .jobs.\"deploy-gitops\".steps[].run
       | select(. != null)
       | select(test(\"tofu apply\"))
       | select(test(\"-target\") | not) ]
     | length == 1
   ' $WF"

# --- Trivy step: soft gate + unfixed filter (challenge-scope compromise) ---
expect "Trivy scan step is marked continue-on-error" \
  "yq -e '[.jobs.\"build-and-push\".steps[] | select(.name == \"Scan image (Trivy)\") | .\"continue-on-error\"] | .[0] == true' $WF"
expect "Trivy invocation uses --ignore-unfixed" \
  "yq -e '[.jobs.\"build-and-push\".steps[] | select(.name == \"Scan image (Trivy)\") | .run | select(. != null) | select(test(\"--ignore-unfixed\"))] | length > 0' $WF"

# --- regression guards on existing jobs ---
expect "check job still exists" \
  "yq -e '.jobs.check' $WF"
expect "build-and-push still gated to challenge" \
  "yq -e '.jobs.\"build-and-push\".if | test(\"refs/heads/challenge\")' $WF"
expect "build-and-push still needs check" \
  "yq -e '.jobs.\"build-and-push\".needs | test(\"check\")' $WF"

[ "$fail" -eq 0 ] || exit 1
echo "All structural assertions passed."
