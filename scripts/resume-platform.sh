#!/usr/bin/env bash
# Resume an existing Terraform-managed cluster after a partial platform apply.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
account=$(aws sts get-caller-identity --query Account --output text)
cat > .runtime/backend.hcl <<BACKEND
bucket = "agribridge-tfstate-$account"
region = "us-east-1"
encrypt = true
use_lockfile = true
BACKEND
export KOPS_STATE_STORE=s3://kops-state-607
kops export kubeconfig k8s.agribridge.deuces.dev --admin=24h --kubeconfig .runtime/kubeconfig
export KUBECONFIG="$PWD/.runtime/kubeconfig"
bash scripts/wait-platform.sh
terraform -chdir=terraform/stacks/03-services init -reconfigure -backend-config=../../../.runtime/backend.hcl -backend-config=key=services/terraform.tfstate
repository=$(git remote get-url origin | sed -E 's#https://github.com/##;s#\.git$##')
subject_prefix=$(gh api "repos/$repository/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty')
subject_prefix=${subject_prefix:-repo:$repository}
terraform -chdir=terraform/stacks/03-services apply -auto-approve \
  -var="discovery_bucket=agribridge-oidc-$account" -var="repository_subject_prefix=$subject_prefix"
terraform -chdir=terraform/stacks/03-services output -json platform | jq --arg path "$KUBECONFIG" \
  '{platform: ., kubeconfig_path: $path}' > .runtime/platform.tfvars.json
terraform -chdir=terraform/stacks/04-platform init -reconfigure -backend-config=../../../.runtime/backend.hcl -backend-config=key=platform/terraform.tfstate
terraform -chdir=terraform/stacks/04-platform apply -auto-approve -var-file=../../../.runtime/platform.tfvars.json
for environment in staging production; do
  gh api --method PUT "repos/$repository/environments/$environment" > /dev/null
done
terraform -chdir=terraform/stacks/03-services output -raw pipeline_role | gh variable set AWS_DEPLOY_ROLE --repo "$repository"
terraform -chdir=terraform/stacks/03-services output -raw registry_namespace | gh variable set DOCKERHUB_USERNAME --repo "$repository"
echo 'Platform ready. Run the delivery workflow from the branch containing these changes.'
