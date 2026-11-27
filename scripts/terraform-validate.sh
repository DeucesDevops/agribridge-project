#!/usr/bin/env bash
# Check Terraform formatting, then init and validate every module and environment.
# There is no plan or apply here. The cluster module receives aws.files from
# the environment root, so this script writes a temporary provider block,
# validates that module, and deletes the block before the roots are validated.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

terraform fmt -check -recursive terraform

modules=(
  terraform/modules/network
  terraform/modules/cluster
  terraform/modules/dns
  terraform/modules/storage
  terraform/modules/identity
  terraform/modules/platform
)
roots=(
  terraform/environments/production
  terraform/environments/dev
  terraform/bootstrap
)

for dir in "${modules[@]}" "${roots[@]}"; do
  terraform -chdir="$dir" init -backend=false -input=false -lockfile=readonly
done

cluster_providers="terraform/modules/cluster/validate-providers.tf"
cleanup() {
  rm -f "$cluster_providers"
}
trap cleanup EXIT

cat >"$cluster_providers" <<'EOF'
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "files"
  region = "us-east-1"
}
EOF

terraform -chdir=terraform/modules/cluster validate -no-color
rm -f "$cluster_providers"
trap - EXIT

for dir in \
  terraform/modules/network \
  terraform/modules/dns \
  terraform/modules/storage \
  terraform/modules/identity \
  terraform/modules/platform \
  "${roots[@]}"
do
  terraform -chdir="$dir" validate -no-color
done
