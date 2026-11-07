#!/usr/bin/env bash
# Generate non-secret GitOps configuration. Does not apply, commit or push.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
python3 -c 'import yaml' || { echo 'Activate .runtime/python-venv first.' >&2; exit 1; }
account=$(aws sts get-caller-identity --query Account --output text)
test "$account" = 237258628535 || { echo 'AWS account mismatch.' >&2; exit 1; }
for environment in staging production; do
  aws ssm get-parameter --region us-east-1 \
    --name "/agribridge/$environment/deployment" --query Parameter.Value --output text \
    > ".runtime/gitops-$environment.json"
  python3 scripts/render-gitops-values.py "$environment" ".runtime/gitops-$environment.json"
done
echo 'GitOps values generated from non-secret deployment parameters. No secret values were fetched.'
