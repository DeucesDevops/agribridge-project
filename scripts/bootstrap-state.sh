#!/usr/bin/env bash
# Create the Terraform state bucket. Terraform cannot create the bucket it
# stores its own state in, so this is the one AWS object made by hand.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${TF_STATE_BUCKET:-agribridge-tfstate-${ACCOUNT}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "State bucket ${BUCKET} already exists."
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
  echo "Created state bucket ${BUCKET}."
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

BACKEND="${ROOT}/terraform/backend.hcl"
if [ -f "$BACKEND" ]; then
  echo "Leaving existing ${BACKEND} in place."
else
  cat >"$BACKEND" <<EOF
bucket       = "${BUCKET}"
key          = "agribridge/terraform.tfstate"
region       = "${REGION}"
encrypt      = true
use_lockfile = true
EOF
  echo "Wrote ${BACKEND}."
fi
