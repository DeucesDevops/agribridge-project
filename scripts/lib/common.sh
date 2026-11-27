#!/usr/bin/env bash
# Names shared by the platform scripts. Source this file. Do not execute it.
# Callers set ROOT to the repository root and enable set -euo pipefail.

if [ -z "${ROOT:-}" ]; then
  echo "Set ROOT to the repository root before sourcing scripts/lib/common.sh." >&2
  exit 1
fi

export AWS_REGION="${AWS_REGION:-us-east-1}"
export KOPS_STATE_STORE="${KOPS_STATE_STORE:-s3://kops-state-607}"
export KOPS_CLUSTER_NAME="${KOPS_CLUSTER_NAME:-k8s.agribridge.deuces.dev}"
export ZONE_NAME="${ZONE_NAME:-agribridge.deuces.dev}"
