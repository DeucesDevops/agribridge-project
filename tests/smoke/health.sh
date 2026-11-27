#!/usr/bin/env bash
# Post-deploy checks for the public site.
# Usage: tests/smoke/health.sh [base-url]
# The default is https://production.agribridge.deuces.dev.
set -euo pipefail

base="${1:-${BASE_URL:-https://production.agribridge.deuces.dev}}"
base="${base%/}"

echo "Checking ${base}"
curl -fsS "${base}/healthz"
echo
curl -fsS "${base}/readyz"
echo
curl -fsS "${base}/version"
echo
