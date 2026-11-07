#!/usr/bin/env bash
# Read GitHub settings and secret NAMES only. Never change credentials/settings.
set -euo pipefail
cd "$(dirname "$0")/.."
repository=DeucesDevops/agribridge-project
gh auth status
test "$(gh api "repos/$repository" --jq '.permissions.push')" = true || {
  echo 'This GitHub identity cannot publish the reviewed source.' >&2; exit 1;
}
test "$(gh api "repos/$repository/actions/permissions" --jq '.enabled')" = true || {
  echo 'GitHub Actions is disabled for this repository.' >&2; exit 1;
}
secrets=$(gh api "repos/$repository/actions/secrets" --paginate --jq '.secrets[].name')
if ! printf '%s\n' "$secrets" | grep -qx DOCKERHUB_TOKEN; then
  echo 'DOCKERHUB_TOKEN is missing. Set it interactively with gh secret set DOCKERHUB_TOKEN.' >&2
  exit 1
fi
if [ "$(gh api "repos/$repository/branches/main" --jq '.protected')" = true ]; then
  echo 'Main is protected: review bot push permissions or select a reviewed PR release design first.' >&2
  exit 1
fi
echo 'GitHub access, Actions and Docker Hub secret name checks passed.'
echo 'Production environment protection rules (metadata only):'
gh api "repos/$repository/environments/production" --jq '.protection_rules[]?.type'
echo 'A production required-reviewer rule pauses promotion; otherwise promotion follows staging automatically.'
