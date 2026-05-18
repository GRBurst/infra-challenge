#!/usr/bin/env bash
#
# Idempotent local-Gitea bootstrap.
#   1. Wait for Gitea API.
#   2. Ensure repo gitea-admin/infra-challenge exists.
#   3. Force-push the current branch.
#   4. Set Gitea default_branch = current branch.

set -euo pipefail

GITEA_URL="${GITEA_URL:-http://localhost:3000}"
ADMIN_USER="${ADMIN_USER:-gitea-admin}"
ADMIN_PASS="${ADMIN_PASS:-gitea-admin}"
REPO_NAME="${REPO_NAME:-infra-challenge}"
TIMEOUT_SECS="${TIMEOUT_SECS:-180}"

REPO_URL="${GITEA_URL}/${ADMIN_USER}/${REPO_NAME}.git"
PUSH_URL="http://${ADMIN_USER}:${ADMIN_PASS}@$(echo "${GITEA_URL}" | sed -E 's#^https?://##')/${ADMIN_USER}/${REPO_NAME}.git"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${CURRENT_BRANCH}" == "HEAD" ]]; then
  echo "ERROR: detached HEAD; checkout a branch first." >&2
  exit 1
fi

echo "==> Waiting for Gitea at ${GITEA_URL} (timeout ${TIMEOUT_SECS}s)..."
deadline=$(( SECONDS + TIMEOUT_SECS ))
until curl -sfo /dev/null "${GITEA_URL}/api/v1/version"; do
  if (( SECONDS >= deadline )); then
    echo "Gitea did not become ready in time." >&2
    exit 1
  fi
  sleep 2
done
echo "    Gitea ready."

echo "==> Ensuring repo ${ADMIN_USER}/${REPO_NAME} exists..."
http_code=$(curl -s -o /tmp/gitea-create.out -w "%{http_code}" \
  -u "${ADMIN_USER}:${ADMIN_PASS}" -H "Content-Type: application/json" \
  -X POST "${GITEA_URL}/api/v1/user/repos" \
  -d "{\"name\":\"${REPO_NAME}\",\"private\":false,\"auto_init\":false,\"default_branch\":\"${CURRENT_BRANCH}\"}")
case "${http_code}" in
  201) echo "    Created.";;
  409) echo "    Already exists.";;
  *)   echo "    Unexpected HTTP ${http_code}:"; cat /tmp/gitea-create.out; exit 1;;
esac

echo "==> Pushing branch ${CURRENT_BRANCH} to gitea..."
git remote remove gitea 2>/dev/null || true
git remote add gitea "${PUSH_URL}"
git push gitea "${CURRENT_BRANCH}:${CURRENT_BRANCH}" --force

echo "==> Setting default_branch = ${CURRENT_BRANCH}..."
curl -sf -u "${ADMIN_USER}:${ADMIN_PASS}" -H "Content-Type: application/json" \
  -X PATCH "${GITEA_URL}/api/v1/repos/${ADMIN_USER}/${REPO_NAME}" \
  -d "{\"default_branch\":\"${CURRENT_BRANCH}\"}" >/dev/null

echo
echo "Gitea ready:"
echo "  Web UI:        ${GITEA_URL}"
echo "  Push remote:   ${REPO_URL}"
echo "  Branch:        ${CURRENT_BRANCH}"
