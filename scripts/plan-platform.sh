#!/usr/bin/env bash
# Validate the services boundary and save a Kubernetes platform plan; never apply.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
for tool in terraform aws kubectl python3; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done

expected_account=237258628535
actual_account=$(aws sts get-caller-identity --query Account --output text)
test "$actual_account" = "$expected_account" || { echo 'AWS account mismatch; stopping.' >&2; exit 1; }
export TF_VAR_expected_account_id="$expected_account"
export TF_VAR_discovery_bucket="agribridge-oidc-$expected_account"
export KUBECONFIG="$PWD/.runtime/kubeconfig"
test -s "$KUBECONFIG" || { echo 'Export the private cluster kubeconfig first.' >&2; exit 1; }
context=$(kubectl config current-context)
server=$(kubectl config view --minify -o 'jsonpath={.clusters[0].cluster.server}')
test "$context" = k8s.agribridge.deuces.dev && \
  test "$server" = https://api.k8s.agribridge.deuces.dev || {
  echo 'Kubernetes context or API server mismatch; stopping.' >&2; exit 1;
}
bash scripts/wait-platform.sh

run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
check_path="$PWD/.runtime/services-check-$run_id.tfplan"
# A saved no-change check is required before moving to the platform boundary.
if terraform -chdir=terraform plan -input=false -detailed-exitcode -out="$check_path"; then
  terraform -chdir=terraform show -no-color "$check_path" > "${check_path%.tfplan}.txt"
else
  check_status=$?
  if [ "$check_status" -eq 2 ]; then
    terraform -chdir=terraform show -no-color "$check_path" > "${check_path%.tfplan}.txt"
    echo "Services have proposed changes. Review ${check_path%.tfplan}.txt before proceeding." >&2
  fi
  exit "$check_status"
fi

# Replace any stale pre-teardown input with the current non-secret service outputs.
terraform -chdir=terraform output -json platform > ".runtime/platform-output-$run_id.json"
if [ -f .runtime/platform.tfvars.json ]; then
  cp -p .runtime/platform.tfvars.json ".runtime/platform-input-before-$run_id.json"
  chmod 600 ".runtime/platform-input-before-$run_id.json"
fi
python3 - ".runtime/platform-output-$run_id.json" <<'PY'
import json, os
from pathlib import Path
import sys
platform = json.loads(Path(sys.argv[1]).read_text())
input_path = Path('.runtime/platform.tfvars.json')
previous = json.loads(input_path.read_text()) if input_path.exists() else {}
argocd_enabled = previous.get('enable_argocd', False)
override = os.environ.get('AGRIBRIDGE_ENABLE_ARGOCD')
if override is not None:
    if override not in ('true', 'false'):
        raise SystemExit('AGRIBRIDGE_ENABLE_ARGOCD must be true or false')
    argocd_enabled = override == 'true'
if not isinstance(argocd_enabled, bool):
    raise SystemExit('Unexpected Argo CD enable flag')
assert platform['region'] == 'us-east-1', 'Unexpected platform region'
assert platform['zone_name'] == 'agribridge.deuces.dev', 'Unexpected DNS zone'
assert platform['certificate_arn'].startswith('arn:aws:acm:us-east-1:237258628535:certificate/'), 'Unexpected certificate'
for key in ['secrets_role', 'logs_role']:
    assert platform[key].startswith('arn:aws:iam::237258628535:role/agribridge-'), 'Unexpected workload role'
assert platform['zone_id'], 'Missing hosted zone ID'
Path('.runtime/platform.tfvars.json').write_text(json.dumps({
    'platform': platform,
    'kubeconfig_path': os.environ['KUBECONFIG'],
    'expected_account_id': '237258628535',
    'enable_legacy_pipeline': False,
    'enable_argocd': argocd_enabled,
}, indent=2) + '\n')
PY

cat > .runtime/platform-backend.hcl <<'BACKEND'
bucket = "agribridge-tfstate-237258628535"
region = "us-east-1"
encrypt = true
use_lockfile = true
BACKEND
terraform -chdir=terraform/platform init -input=false -reconfigure -lockfile=readonly \
  -backend-config=../../.runtime/platform-backend.hcl -backend-config=key=platform/terraform.tfstate
terraform -chdir=terraform/platform validate -no-color

state_key=$(aws s3api list-objects-v2 --region us-east-1 \
  --bucket "agribridge-tfstate-$expected_account" --prefix platform/terraform.tfstate \
  --query "Contents[?Key=='platform/terraform.tfstate'].Key | [0]" --output text)
if [ "$state_key" = platform/terraform.tfstate ]; then
  terraform -chdir=terraform/platform state pull > ".runtime/platform-before-$run_id.tfstate"
elif [ "$state_key" != None ]; then
  echo 'Unexpected platform state listing; stopping.' >&2
  exit 1
fi

plan_path="$PWD/.runtime/platform-$run_id.tfplan"
terraform -chdir=terraform/platform plan -input=false \
  -var-file=../../.runtime/platform.tfvars.json -out="$plan_path"
terraform -chdir=terraform/platform show -no-color "$plan_path" > "${plan_path%.tfplan}.txt"
echo "Saved plan: $plan_path"
echo "Readable review: ${plan_path%.tfplan}.txt"
echo 'No platform resources were applied. Applying later can create a chargeable NLB and monitoring EBS volumes.'
