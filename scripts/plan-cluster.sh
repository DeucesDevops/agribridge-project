#!/usr/bin/env bash
# Generate and plan the cluster. Stores kOps metadata in S3; never applies nodes.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
for tool in terraform kops python3 curl dig aws; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
python3 -c 'import yaml' || {
  echo 'PyYAML is required by the kOps helpers. Install it in your Python environment first.' >&2
  exit 1
}

run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
export CLUSTER_NAME=k8s.agribridge.deuces.dev
export EXPECTED_AWS_ACCOUNT_ID=237258628535
actual_account=$(aws sts get-caller-identity --query Account --output text)
test "$actual_account" = "$EXPECTED_AWS_ACCOUNT_ID" || { echo 'AWS account mismatch; stopping.' >&2; exit 1; }
export TF_VAR_expected_account_id="$EXPECTED_AWS_ACCOUNT_ID"
terraform -chdir=terraform/bootstrap output -json > .runtime/bootstrap-outputs.json
dig +time=3 +tries=1 +short NS agribridge.deuces.dev > .runtime/delegated-nameservers.txt
python3 - <<'PY'
import json
from pathlib import Path
outputs = json.loads(Path('.runtime/bootstrap-outputs.json').read_text())
expected = {s.rstrip('.').lower() for s in outputs['name_servers']['value']}
observed = {s.strip().rstrip('.').lower() for s in Path('.runtime/delegated-nameservers.txt').read_text().splitlines() if s.strip()}
if observed != expected:
    raise SystemExit('DNS delegation does not yet match the new hosted zone; retry after propagation.')
assert outputs['bucket']['value'] == 'agribridge-tfstate-237258628535'
assert outputs['kops_state_store']['value'] == 's3://kops-state-607'
print('Account, bootstrap outputs and public DNS delegation match.')
PY

# Optional comma-separated CIDRs for an approved VPN/operator network. By default
# use only this workstation's public IPv4; never write that address into Git.
if [ -z "${AGRIBRIDGE_API_CIDRS:-}" ]; then
  operator_ip=$(curl -4 --fail --silent --show-error --max-time 10 https://checkip.amazonaws.com)
  export AGRIBRIDGE_API_CIDRS="$operator_ip/32"
fi
python3 scripts/render-cluster.py

export KOPS_STATE_STORE=s3://kops-state-607
cat > .runtime/backend.hcl <<'BACKEND'
bucket = "agribridge-tfstate-237258628535"
region = "us-east-1"
encrypt = true
use_lockfile = true
BACKEND
# Keep a protected recovery copy of bootstrap state in its versioned bucket.
aws s3 cp terraform/bootstrap/terraform.tfstate \
  s3://agribridge-tfstate-237258628535/bootstrap/terraform.tfstate --only-show-errors

# kOps exits 1 for an empty store. Only that specific terminal error means
# absence; access, missing-bucket and network errors must still stop the plan.
if kops get clusters -o json > .runtime/kops-clusters.json 2> .runtime/kops-clusters.stderr; then
  :
else
  list_status=$?
  if [ "$list_status" -eq 1 ] && [ ! -s .runtime/kops-clusters.json ] && \
    [ "$(tail -n 1 .runtime/kops-clusters.stderr)" = 'Error: no clusters found' ]; then
    printf '[]\n' > .runtime/kops-clusters.json
    echo 'No existing clusters in the kOps store; preparing the first cluster.'
  else
    cat .runtime/kops-clusters.stderr >&2
    exit "$list_status"
  fi
fi
exists=$(python3 - <<'PY'
import json, os
from pathlib import Path
data = json.loads(Path('.runtime/kops-clusters.json').read_text())
if isinstance(data, list):
    items = data
elif 'items' in data:
    items = data['items'] or []
elif data.get('kind') == 'Cluster':
    items = [data]
else:
    raise SystemExit('Unexpected cluster-list response; refusing to guess.')
print('yes' if any(d['metadata']['name'] == os.environ['CLUSTER_NAME'] for d in items) else 'no')
PY
)
if [ "$exists" = yes ]; then
  kops get cluster "$CLUSTER_NAME" -o yaml > ".runtime/cluster-before-$run_id.yaml"
  kops get instancegroups --name "$CLUSTER_NAME" -o yaml > ".runtime/instancegroups-before-$run_id.yaml"
  kops replace -f .runtime/cluster.yaml
else
  kops create -f .runtime/cluster.yaml
fi
kops update cluster "$CLUSTER_NAME" --target terraform --out terraform/generated/kops --create-kube-config=false
python3 scripts/prepare-kops-module.py
python3 scripts/patch-kops-bootstrap.py
terraform fmt -recursive terraform
terraform -chdir=terraform/cluster init -input=false -reconfigure -lockfile=readonly \
  -backend-config=../../.runtime/backend.hcl -backend-config=key=kops/terraform.tfstate
terraform -chdir=terraform/cluster validate -no-color
plan_path="$PWD/.runtime/cluster-$run_id.tfplan"
terraform -chdir=terraform/cluster plan -input=false -out="$plan_path"
terraform -chdir=terraform/cluster show -no-color "$plan_path" > "${plan_path%.tfplan}.txt"
echo "Saved plan: $plan_path"
echo "Readable review: ${plan_path%.tfplan}.txt"
echo 'kOps metadata and bootstrap-state backup were saved in S3. No cluster infrastructure was applied.'
