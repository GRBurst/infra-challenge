# justfile — OpenTofu infrastructure helper commands
# Requires: https://github.com/casey/just

set dotenv-load := false
set export := true

PLAN := env_var_or_default("PLAN", "plan.tfplan")
ARGS := env_var_or_default("ARGS", "")

repo_root := justfile_directory()

default:
  @just --list

# ============================================================
# Format
# ============================================================

# Check: OpenTofu formatting
fmt-tofu-check:
  tofu fmt -check -recursive

# Fix: OpenTofu formatting
fmt-tofu:
  tofu fmt -recursive

# Check: Nix formatting (treefmt --ci)
fmt-nix-check:
  treefmt --ci

# Fix: Nix formatting
fmt-nix:
  treefmt

# Check: YAML formatting
fmt-yaml-check:
  yamlfmt -gitignore_excludes -exclude 'refs/**/*' -exclude 'charts/greeter/templates/**' -lint -dstar '**/*.{yml,yaml}'

# Fix: YAML formatting
fmt-yaml:
  yamlfmt -gitignore_excludes -exclude 'refs/**/*' -exclude 'charts/greeter/templates/**' -dstar '**/*.{yml,yaml}'

# Check: Markdown formatting
fmt-md-check:
  #!/usr/bin/env bash
  set -euo pipefail
  git ls-files -z -- '*.md' ':(exclude)refs/**' \
    | xargs -0 --no-run-if-empty mdformat --check

# Fix: Markdown formatting
fmt-md:
  #!/usr/bin/env bash
  set -euo pipefail
  git ls-files -z -- '*.md' ':(exclude)refs/**' \
    | xargs -0 --no-run-if-empty mdformat

# Check: all formatting (CI equivalent)
fmt-check: fmt-tofu-check fmt-nix-check fmt-yaml-check fmt-md-check

# Fix: all formatting
fmt: fmt-tofu fmt-nix fmt-yaml fmt-md

# ============================================================
# Lint
# ============================================================

# Check: trailing whitespace, merge conflicts, CRLF, private keys, EOF newlines
lint-core:
  #!/usr/bin/env bash
  set -euo pipefail
  fail=0

  echo "--- Trailing whitespace ---"
  if git ls-files -z | grep -zvE 'snap_test.*\.py$' \
      | xargs -0 grep -InE '[[:blank:]]$' 2>/dev/null; then
    echo "FAIL: trailing whitespace found"; fail=1
  fi

  echo "--- Merge conflicts ---"
  if git ls-files -z | xargs -0 grep -In '^<<<<<<< ' 2>/dev/null; then
    echo "FAIL: merge conflict markers found"; fail=1
  fi

  echo "--- CRLF line endings ---"
  if git ls-files -z | xargs -0 grep -IPn '\r$' 2>/dev/null; then
    echo "FAIL: CRLF line endings found"; fail=1
  fi

  echo "--- Private keys ---"
  if git ls-files -z | xargs -0 grep -InE 'BEGIN (RSA|DSA|EC|OPENSSH|PRIVATE) KEY' 2>/dev/null; then
    echo "FAIL: private key detected"; fail=1
  fi

  echo "--- EOF newlines ---"
  while IFS= read -r f; do
    if [ -s "$f" ] && [ "$(tail -c 1 "$f" | wc -l)" -eq 0 ]; then
      echo "Missing EOF newline: $f"; fail=1
    fi
  done < <(git ls-files)

  [ "$fail" -eq 0 ] || exit 1
  echo "All core checks passed."

# Fix: trailing whitespace and missing EOF newlines (auto-fixable)
lint-core-fix:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "--- Fixing trailing whitespace ---"
  git ls-files -z | grep -zvE 'snap_test.*\.py$' \
    | xargs -0 sed -i 's/[[:blank:]]*$//' || true

  echo "--- Fixing CRLF line endings ---"
  git ls-files -z | xargs -0 sed -i 's/\r$//' || true

  echo "--- Fixing missing EOF newlines ---"
  while IFS= read -r f; do
    if [ -s "$f" ] && [ "$(tail -c 1 "$f" | wc -l)" -eq 0 ]; then
      echo "" >> "$f"
      echo "Fixed: $f"
    fi
  done < <(git ls-files)

  echo "Done. Re-run lint-core to verify."

# Check: YAML lint
lint-yaml:
  yamllint .

# Check: all lint checks (core + yaml)
lint: lint-core lint-yaml

# Fix: all auto-fixable lint issues
lint-fix: lint-core-fix

# ============================================================
# Validate
# ============================================================

# Validate all environments that contain Terraform configuration
validate:
  #!/usr/bin/env bash
  set -euo pipefail
  while IFS= read -r dir; do
    echo "--- Validating $dir ---"
    (cd "$dir" && tofu init -backend=false -input=false -no-color && tofu validate -no-color)
  done < <(find envs -name 'main.tf' -exec dirname {} \; | sort)

# Run TFLint across the repository
tflint:
  tflint --init --config "{{repo_root}}/.tflint.hcl"
  tflint --chdir=envs --recursive --config "{{repo_root}}/.tflint.hcl" --call-module-type=local
  tflint --chdir=modules --recursive --config "{{repo_root}}/.tflint.hcl"

# ============================================================
# Security
# ============================================================

# Run Trivy IaC security scan
security:
  trivy config .

# ============================================================
# Test
# ============================================================

# Run OpenTofu native tests for all modules that have test files
test:
  #!/usr/bin/env bash
  set -euo pipefail
  while IFS= read -r dir; do
    echo "--- Testing $dir ---"
    (cd "$dir" && tofu init -backend=false -input=false -no-color && tofu test -no-color)
  done < <(find modules -name '*.tftest.hcl' -exec dirname {} \; | sort -u)

# Run Go tests
test-go:
  GO111MODULE=off go test -v

# Run Helm lint and unit tests
test-chart:
  helm lint charts/greeter
  helm unittest charts/greeter

# Run OpenTofu tests for gitops module and local env
test-tofu:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "--- Testing modules/gitops ---"
  (cd modules/gitops && tofu init -backend=false -input=false -no-color && tofu test -no-color)
  echo "--- Testing envs/local ---"
  (cd envs/local && tofu init -backend=false -input=false -no-color && tofu test -no-color)

# Run all tests: Go, Helm, OpenTofu, and static checks
test-all: test-go test-chart test-tofu test-gitea-script

# ============================================================
# Local dev lifecycle
# ============================================================

# Bring up local k3d cluster, push image, apply GitOps stack
dev-up:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! k3d cluster list | grep -q infra-challenge; then
    k3d cluster create --config local/k3d-config.yaml
  else
    k3d cluster start infra-challenge 2>/dev/null || true
  fi
  until curl -sf http://registry.localhost:5001/v2/ >/dev/null 2>&1; do sleep 1; done
  just dev-image
  cd envs/local && tofu init \
    && tofu apply -target=module.gitops.helm_release.argocd -auto-approve \
    && tofu apply -auto-approve

# Build and push greeter image to local registry
dev-image:
  nix build .#dockerImage
  docker load < result
  docker tag greeter:latest registry.localhost:5001/greeter:local
  docker push registry.localhost:5001/greeter:local

# Install/upgrade greeter chart directly (without ArgoCD sync)
dev-deploy:
  helm upgrade --install greeter charts/greeter \
    -f charts/greeter/values-local.yaml \
    -n greeter --create-namespace \
    --kube-context k3d-infra-challenge

# Run smoke tests against local cluster
dev-test:
  bash local/scripts/smoke-test.sh

# Tear down local k3d cluster
dev-down:
  k3d cluster delete infra-challenge

# ============================================================
# Local Gitea (optional, fully offline GitOps)
# ============================================================

# Phased: cluster → image → gitea → push current branch → argocd → app CR
dev-up-gitea:
  #!/usr/bin/env bash
  set -euo pipefail
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" == "HEAD" ]]; then
    echo "ERROR: detached HEAD; checkout a branch first." >&2; exit 1
  fi
  if ! k3d cluster list | grep -q infra-challenge; then
    k3d cluster create --config local/k3d-config.yaml
  else
    k3d cluster start infra-challenge 2>/dev/null || true
  fi
  until curl -sf http://registry.localhost:5001/v2/ >/dev/null 2>&1; do sleep 1; done
  just dev-image
  cd envs/local && \
    tofu init && \
    tofu apply -auto-approve \
      -var gitea_enabled=true -var "greeter_branch=$branch" \
      -target=helm_release.gitea
  cd "{{repo_root}}" && bash local/scripts/gitea-setup.sh
  cd envs/local && \
    tofu apply -auto-approve \
      -var gitea_enabled=true -var "greeter_branch=$branch" \
      -target=module.gitops.helm_release.argocd
  cd envs/local && \
    tofu apply -auto-approve \
      -var gitea_enabled=true -var "greeter_branch=$branch"
  echo
  echo "Gitea web:  http://localhost:3000  (gitea-admin / gitea-admin)"
  echo "Branch:     $branch"
  echo "ArgoCD UI:  just argocd-ui"

# Force-push current branch to Gitea (idempotent)
gitea-setup:
  bash local/scripts/gitea-setup.sh

# Force ArgoCD to re-evaluate immediately after `git push gitea`
gitea-sync:
  kubectl --context k3d-infra-challenge -n argocd \
    annotate app greeter argocd.argoproj.io/refresh=hard --overwrite

# Print ArgoCD port-forward command and initial admin password
argocd-ui:
  @echo "kubectl --context k3d-infra-challenge port-forward svc/argocd-server -n argocd 8080:80"
  @echo "Initial admin password:"
  @kubectl --context k3d-infra-challenge -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d
  @echo

# Static-check gitea-setup.sh
test-gitea-script:
  shellcheck local/scripts/gitea-setup.sh
  bash -n local/scripts/gitea-setup.sh

# ============================================================
# Aggregated
# ============================================================

# Run all checks (full CI equivalent)
check: fmt-check lint validate tflint

# Apply all auto-fixable changes (format + fixable lint)
fix: fmt lint-fix

# ============================================================
# Lifecycle
# ============================================================

# Initialize OpenTofu working directory
[no-cd]
init:
  tofu init {{ARGS}}

# Upgrade providers and modules
[no-cd]
upgrade:
  tofu init -upgrade {{ARGS}}

# Plan infrastructure changes
[no-cd]
plan: init
  tofu plan {{ARGS}}

# Apply infrastructure changes
[no-cd]
apply: init
  @if [ -f "{{PLAN}}" ]; then \
    tofu apply {{ARGS}} "{{PLAN}}"; \
  else \
    tofu apply {{ARGS}}; \
  fi

# ============================================================
# State helpers
# ============================================================

[no-cd]
outputs:
  tofu output

[no-cd]
state-list:
  tofu state list

[no-cd]
state-pull:
  tofu state pull > tofu.tfstate

[no-cd]
providers:
  tofu providers

# ============================================================
# Cleanup
# ============================================================

clean:
  @rm -rf .terraform .terraform.lock.hcl "{{PLAN}}"
