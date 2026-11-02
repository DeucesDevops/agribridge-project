#!/usr/bin/env bash
# Prepare a reviewable Terraform plan. Does not apply or import AWS resources.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
plan_path="$PWD/.runtime/bootstrap-$run_id.tfplan"

# Preserve the previous local state before Terraform refreshes resource reads.
if [ -f terraform/bootstrap/terraform.tfstate ]; then
  cp -p terraform/bootstrap/terraform.tfstate ".runtime/bootstrap-before-$run_id.tfstate"
  chmod 600 ".runtime/bootstrap-before-$run_id.tfstate"
fi

terraform -chdir=terraform/bootstrap init -input=false -lockfile=readonly
terraform -chdir=terraform/bootstrap validate -no-color
terraform -chdir=terraform/bootstrap plan -input=false -out="$plan_path"
terraform -chdir=terraform/bootstrap show -no-color "$plan_path" > "${plan_path%.tfplan}.txt"

echo "Saved plan: $plan_path"
echo "Readable review: ${plan_path%.tfplan}.txt"
echo 'No AWS resources were applied. Review the plan before requesting an apply.'
