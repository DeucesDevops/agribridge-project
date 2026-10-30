#!/usr/bin/env bash
# Prerequisites: AWS CLI, Terraform >=1.10, kOps 1.36.2, kubectl, Helm, jq,
# Python 3 + PyYAML, and gh authenticated to the target repository.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
account=$(aws sts get-caller-identity --query Account --output text)
state_bucket="agribridge-tfstate-$account"
# Bootstrap state has no app secrets; keep an encrypted S3 recovery copy.
if [ ! -f terraform/stacks/01-bootstrap/terraform.tfstate ]; then
  aws s3 cp "s3://$state_bucket/bootstrap/terraform.tfstate" terraform/stacks/01-bootstrap/terraform.tfstate --only-show-errors 2>/dev/null || true
fi
terraform -chdir=terraform/stacks/01-bootstrap init
# Adopt only the pre-existing resources named in the bootstrap configuration.
if ! terraform -chdir=terraform/stacks/01-bootstrap state show module.bootstrap.aws_s3_bucket.kops >/dev/null 2>&1 && \
   ! terraform -chdir=terraform/stacks/01-bootstrap state show aws_s3_bucket.kops >/dev/null 2>&1; then
  if aws s3api head-bucket --bucket kops-state-607 2>/dev/null; then
    terraform -chdir=terraform/stacks/01-bootstrap import module.bootstrap.aws_s3_bucket.kops kops-state-607
  fi
fi
if ! terraform -chdir=terraform/stacks/01-bootstrap state show module.bootstrap.aws_route53_zone.app >/dev/null 2>&1 && \
   ! terraform -chdir=terraform/stacks/01-bootstrap state show aws_route53_zone.app >/dev/null 2>&1; then
  zone_id=$(aws route53 list-hosted-zones-by-name --dns-name agribridge.deuces.dev --query "HostedZones[?Name=='agribridge.deuces.dev.'].Id | [0]" --output text)
  if [ "$zone_id" != None ]; then
    terraform -chdir=terraform/stacks/01-bootstrap import module.bootstrap.aws_route53_zone.app "$zone_id"
  fi
fi
terraform -chdir=terraform/stacks/01-bootstrap apply -auto-approve
aws s3 cp terraform/stacks/01-bootstrap/terraform.tfstate "s3://$state_bucket/bootstrap/terraform.tfstate" --only-show-errors
cat > .runtime/backend.hcl <<BACKEND
bucket = "$state_bucket"
region = "us-east-1"
encrypt = true
use_lockfile = true
BACKEND
export KOPS_STATE_STORE
KOPS_STATE_STORE=$(terraform -chdir=terraform/stacks/01-bootstrap output -raw kops_state_store)
cluster=k8s.agribridge.deuces.dev
# The checked-in manifest is the editable source; generated files are reviewed output.
python3 - "$account" <<'PY'
import sys
from pathlib import Path
import yaml
p = Path('kops/cluster.yaml')
docs = list(yaml.safe_load_all(p.read_text()))
docs[0]['spec']['serviceAccountIssuerDiscovery']['discoveryStore'] = f's3://agribridge-oidc-{sys.argv[1]}'
p.write_text(yaml.safe_dump_all(docs, sort_keys=False))
PY
if kops get cluster "$cluster" >/dev/null 2>&1; then
  kops replace -f kops/cluster.yaml
else
  kops create -f kops/cluster.yaml
fi
kops update cluster "$cluster" --target terraform --out terraform/generated/kops
python3 scripts/prepare-kops-module.py
python3 scripts/patch-kops-bootstrap.py

terraform fmt -recursive terraform
terraform -chdir=terraform/stacks/02-cluster init -reconfigure -backend-config=../../../.runtime/backend.hcl -backend-config=key=kops/terraform.tfstate
terraform -chdir=terraform/stacks/02-cluster apply -auto-approve
kops export kubeconfig "$cluster" --admin=24h --kubeconfig .runtime/kubeconfig
export KUBECONFIG="$PWD/.runtime/kubeconfig"
kops validate cluster "$cluster" --wait 15m
# Node readiness alone does not guarantee admission webhooks are serving.
# Platform Service creation fails closed until the AWS controller is ready.
bash scripts/wait-platform.sh
terraform -chdir=terraform/stacks/03-services init -reconfigure -backend-config=../../../.runtime/backend.hcl -backend-config=key=services/terraform.tfstate
repository=$(git remote get-url origin | sed -E 's#https://github.com/##;s#\.git$##')
subject_prefix=$(gh api "repos/$repository/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty')
subject_prefix=${subject_prefix:-repo:$repository}
terraform -chdir=terraform/stacks/03-services apply -auto-approve -var="discovery_bucket=agribridge-oidc-$account" -var="repository_subject_prefix=$subject_prefix"
terraform -chdir=terraform/stacks/03-services output -json platform | jq --arg path "$KUBECONFIG" '{platform: ., kubeconfig_path: $path}' > .runtime/platform.tfvars.json
terraform -chdir=terraform/stacks/04-platform init -reconfigure -backend-config=../../../.runtime/backend.hcl -backend-config=key=platform/terraform.tfstate
terraform -chdir=terraform/stacks/04-platform apply -auto-approve -var-file=../../../.runtime/platform.tfvars.json
repository=$(git remote get-url origin | sed -E 's#https://github.com/##;s#\.git$##')
for environment in staging production; do
  gh api --method PUT "repos/$repository/environments/$environment" > /dev/null
done
terraform -chdir=terraform/stacks/03-services output -raw pipeline_role | gh variable set AWS_DEPLOY_ROLE --repo "$repository"
terraform -chdir=terraform/stacks/03-services output -raw registry_namespace | gh variable set DOCKERHUB_USERNAME --repo "$repository"
echo 'Infrastructure ready. Push main or dispatch delivery.yaml to run all checks and deploy.'
