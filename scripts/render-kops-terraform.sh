#!/usr/bin/env bash
# Refresh terraform/kops from kops/cluster.yaml.
# Run this after the state bucket and the Route 53 zone exist. kOps writes the
# cluster certificates into the state bucket and the Terraform that creates
# the instances. The two have to come from the same run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export KOPS_STATE_STORE="${KOPS_STATE_STORE:-s3://kops-state-607}"
CLUSTER="${KOPS_CLUSTER_NAME:-k8s.agribridge.deuces.dev}"

command -v kops >/dev/null
kops replace -f kops/cluster.yaml --force --name "$CLUSTER"
kops update cluster --name "$CLUSTER" --target=terraform --out=terraform/kops
python3 scripts/patch_kops_terraform.py
terraform -chdir=terraform fmt -recursive >/dev/null
echo "terraform/kops now matches ${KOPS_STATE_STORE}."
