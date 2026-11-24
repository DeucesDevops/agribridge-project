#!/usr/bin/env bash
# Refresh the network and cluster modules from kops/cluster.yaml.
# Run this after the state bucket and the Route 53 zone exist. kOps writes the
# cluster certificates into the state bucket and the Terraform that creates
# the instances. The two have to come from the same run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export KOPS_STATE_STORE="${KOPS_STATE_STORE:-s3://kops-state-607}"
CLUSTER="${KOPS_CLUSTER_NAME:-k8s.agribridge.deuces.dev}"
OUT="terraform/modules/cluster"

command -v kops >/dev/null
kops replace -f kops/cluster.yaml --force --name "$CLUSTER"
kops update cluster --name "$CLUSTER" --target=terraform --out="$OUT"
python3 scripts/patch_kops_terraform.py
for file in \
  "$OUT/main.tf" \
  "$OUT/iam.tf" \
  "$OUT/security-groups.tf" \
  "$OUT/variables.tf" \
  "$OUT/outputs.tf" \
  "$OUT/versions.tf" \
  terraform/modules/network/main.tf \
  terraform/modules/network/outputs.tf
do
  if [ ! -f "$file" ]; then
    echo "kOps render did not leave ${file} in place." >&2
    exit 1
  fi
done
if [ -f "$OUT/kubernetes.tf" ]; then
  echo "kOps output kubernetes.tf is still present. The patch script should remove it." >&2
  exit 1
fi
terraform fmt -recursive terraform >/dev/null
echo "terraform/modules/network and terraform/modules/cluster now match ${KOPS_STATE_STORE}."
