#!/usr/bin/env bash
# Create the AgriBridge environment. Safe to run again.
# The first successful run stops if DNS is not delegated yet. Delegate the
# name servers it prints, then run it again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ZONE_NAME="${ZONE_NAME:-agribridge.deuces.dev}"
REPO="${GITHUB_REPOSITORY:-DeucesDevops/agribridge-project}"
REPO_NAME="${REPO#*/}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Export GITHUB_TOKEN before this script. Use a classic token with the repo scope, or a fine-grained token that can write Actions variables and Administration on ${REPO}."
  exit 1
fi

aws sts get-caller-identity >/dev/null
./scripts/bootstrap-state.sh
terraform -chdir=terraform init -backend-config=backend.hcl -input=false

in_state() {
  terraform -chdir=terraform state show "$1" >/dev/null 2>&1
}

forget() {
  if in_state "$1"; then
    echo "Removing ${1} from state so Terraform leaves the AWS object alone."
    terraform -chdir=terraform state rm "$1"
  fi
}

move() {
  local from="$1"
  local to="$2"
  if in_state "$from" && ! in_state "$to"; then
    echo "Moving state ${from} -> ${to}"
    terraform -chdir=terraform state mv "$from" "$to"
  fi
}

# These buckets used to be in this root. They are not part of the EKS
# environment. Dropping them from state keeps them in the account.
for address in \
  aws_s3_bucket.kops_state \
  aws_s3_bucket_versioning.kops_state \
  aws_s3_bucket_server_side_encryption_configuration.kops_state \
  aws_s3_bucket_public_access_block.kops_state \
  aws_s3_bucket.discovery \
  aws_s3_bucket_public_access_block.discovery \
  aws_s3_bucket_policy.discovery \
  data.aws_route53_zone.app \
  'data.aws_iam_openid_connect_provider.kops[0]'
do
  forget "$address"
done

move 'aws_iam_role.external_secrets[0]' aws_iam_role.external_secrets
move 'aws_iam_role_policy.external_secrets[0]' aws_iam_role_policy.external_secrets
move 'aws_iam_role.external_dns[0]' aws_iam_role.external_dns
move 'aws_iam_role_policy.external_dns[0]' aws_iam_role_policy.external_dns

ZONE_ID="$(aws route53 list-hosted-zones-by-name --dns-name "$ZONE_NAME" \
  --query "HostedZones[?Name=='${ZONE_NAME}.'].Id | [0]" --output text)"
if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "None" ] && ! in_state aws_route53_zone.app; then
  terraform -chdir=terraform import aws_route53_zone.app "${ZONE_ID#/hostedzone/}"
fi

import_github() {
  local address="$1"
  local api_path="$2"
  local import_id="$3"
  if in_state "$address"; then
    return
  fi
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/${api_path}")"
  if [ "$code" = "200" ]; then
    terraform -chdir=terraform import "$address" "$import_id"
  fi
}

import_github 'github_repository_environment.qa[0]' \
  "environments/qa" "${REPO_NAME}:qa"
import_github 'github_repository_environment.production[0]' \
  "environments/production" "${REPO_NAME}:production"

for name in AWS_ROLE_ARN AWS_REGION ACM_CERTIFICATE_ARN CLUSTER_NAME ZONE_NAME \
  QA_URL PRODUCTION_URL GRAFANA_URL BACKUP_BUCKET BACKUP_ROLE_PRODUCTION BACKUP_ROLE_QA
do
  import_github "github_actions_variable.this[\"${name}\"]" \
    "actions/variables/${name}" "${REPO_NAME}:${name}"
done

terraform -chdir=terraform apply -var install_platform=false -target=aws_route53_zone.app

echo "Route 53 name servers for ${ZONE_NAME}:"
terraform -chdir=terraform output name_servers

if [ "${AGRIBRIDGE_DNS_READY:-}" != "1" ]; then
  if ! command -v dig >/dev/null 2>&1; then
    echo "Install dig, or re-run with AGRIBRIDGE_DNS_READY=1 after the name servers answer for ${ZONE_NAME}."
    exit 2
  fi
  actual="$(dig +short NS "$ZONE_NAME" | sed 's/\.$//' | tr '[:upper:]' '[:lower:]' | sort)"
  expected="$(terraform -chdir=terraform output -json name_servers | python3 -c 'import json,sys; print("\n".join(sorted(item.rstrip(".").lower() for item in json.load(sys.stdin))))')"
  if [ "$actual" != "$expected" ]; then
    echo "Delegate those name servers at the registrar for the parent domain, wait until they answer, then run this script again."
    exit 2
  fi
fi

terraform -chdir=terraform apply -var install_platform=false
terraform -chdir=terraform apply -var install_platform=true

echo "Cluster kubeconfig:"
terraform -chdir=terraform output -raw kubeconfig_command
echo
echo "Grafana password:"
echo "aws secretsmanager get-secret-value --secret-id agribridge/grafana --query SecretString --output text"
