#!/usr/bin/env bash
# Create the Terraform state bucket. Terraform cannot create the bucket it
# stores its own state in, so this root uses local state. The production and
# dev roots point backend.hcl at the bucket this script creates.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${TF_STATE_BUCKET:-agribridge-tfstate-${ACCOUNT}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOTSTRAP="${ROOT}/terraform/bootstrap"

terraform -chdir="$BOOTSTRAP" init -input=false
if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  if ! terraform -chdir="$BOOTSTRAP" state show aws_s3_bucket.state >/dev/null 2>&1; then
    echo "Importing existing state bucket ${BUCKET}."
    terraform -chdir="$BOOTSTRAP" import -input=false \
      -var "region=${REGION}" -var "bucket_name=${BUCKET}" \
      aws_s3_bucket.state "$BUCKET"
  else
    echo "State bucket ${BUCKET} is already in the bootstrap state."
  fi
fi

terraform -chdir="$BOOTSTRAP" apply -input=false -auto-approve \
  -var "region=${REGION}" -var "bucket_name=${BUCKET}"
BUCKET="$(terraform -chdir="$BOOTSTRAP" output -raw bucket_name)"

write_backend() {
  local path="$1"
  local key="$2"
  if [ -f "$path" ]; then
    echo "Leaving existing ${path} in place."
    return
  fi
  cat >"$path" <<EOF
bucket       = "${BUCKET}"
key          = "${key}"
region       = "${REGION}"
encrypt      = true
use_lockfile = true
EOF
  echo "Wrote ${path}."
}

write_backend "${ROOT}/terraform/environments/production/backend.hcl" "agribridge/terraform.tfstate"
write_backend "${ROOT}/terraform/environments/dev/backend.hcl" "agribridge/dev/terraform.tfstate"
