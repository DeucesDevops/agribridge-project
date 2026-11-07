#!/usr/bin/env bash
# Save the next AWS services plan for review; never apply or recover secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
for tool in terraform aws python3; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done

expected_account=237258628535
actual_account=$(aws sts get-caller-identity --query Account --output text)
test "$actual_account" = "$expected_account" || { echo 'AWS account mismatch; stopping.' >&2; exit 1; }
export TF_VAR_expected_account_id="$expected_account"
export TF_VAR_discovery_bucket="agribridge-oidc-$expected_account"

# Preserve the services backend boundary established by the original project.
cat > .runtime/services-backend.hcl <<'BACKEND'
bucket = "agribridge-tfstate-237258628535"
region = "us-east-1"
encrypt = true
use_lockfile = true
BACKEND

run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
terraform -chdir=terraform init -input=false -reconfigure -lockfile=readonly \
  -backend-config=../.runtime/services-backend.hcl -backend-config=key=services/terraform.tfstate
terraform -chdir=terraform validate -no-color

# Distinguish an absent state key from an unreadable backend. Failed listing
# must stop; a fresh rebuild legitimately has no services state to back up.
state_key=$(aws s3api list-objects-v2 --region us-east-1 \
  --bucket "agribridge-tfstate-$expected_account" --prefix services/terraform.tfstate \
  --query "Contents[?Key=='services/terraform.tfstate'].Key | [0]" --output text)
if [ "$state_key" = services/terraform.tfstate ]; then
  terraform -chdir=terraform state pull > ".runtime/services-before-$run_id.tfstate"
  python3 - ".runtime/services-before-$run_id.tfstate" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
state = json.loads(path.read_text())
if not isinstance(state.get('resources', []), list):
    raise SystemExit('Unexpected services state; stopping.')
PY
elif [ "$state_key" = None ]; then
  echo 'No previous services state exists; preparing a fresh plan.'
else
  echo 'Unexpected services state listing; stopping.' >&2
  exit 1
fi

plan_path="$PWD/.runtime/services-$run_id.tfplan"
terraform -chdir=terraform plan -input=false -out="$plan_path"
terraform -chdir=terraform show -no-color "$plan_path" > "${plan_path%.tfplan}.txt"
echo "Saved plan: $plan_path"
echo "Readable review: ${plan_path%.tfplan}.txt"
echo 'Plan artifacts may contain sensitive values; keep them private under .runtime/.'
echo 'No services were applied, secrets restored, Kubernetes resources installed or GitHub settings changed.'
