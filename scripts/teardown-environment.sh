#!/usr/bin/env bash
# Remove the environment. terraform -chdir=terraform/environments/production destroy
# is the wrong first command.
# Argo CD owns the application. Delete that Application while Argo CD is still
# running so its finalizer removes the Ingress. ExternalDNS does not delete the
# records it created, and the kOps buckets are marked prevent_destroy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION
export KOPS_STATE_STORE="${KOPS_STATE_STORE:-s3://kops-state-607}"
export KOPS_CLUSTER_NAME="${KOPS_CLUSTER_NAME:-k8s.agribridge.deuces.dev}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Export GITHUB_TOKEN. Terraform removes the Actions variables and environments it created."
  exit 1
fi

if kops export kubeconfig --admin --name "$KOPS_CLUSTER_NAME" >/dev/null 2>&1; then
  kubectl delete application agribridge --namespace argocd --wait=true --timeout=180s || true
  helm uninstall agribridge --namespace agribridge-production || true
  echo "Waiting for Kubernetes load balancers to disappear."
  for _ in $(seq 1 30); do
    count="$(aws elbv2 describe-load-balancers --region "$REGION" \
      --query "length(LoadBalancers[?starts_with(LoadBalancerName, 'k8s-')])" --output text)"
    if [ "$count" = "0" ]; then
      break
    fi
    sleep 10
  done
  terraform -chdir=terraform/environments/production destroy -var install_platform=true -target=module.platform || \
    echo "If this stopped on the platform module, run: terraform -chdir=terraform/environments/production state rm 'module.platform[\"production\"]'"
else
  echo "The cluster API did not answer. Skipping the Helm uninstall."
fi

ZONE_ID="$(terraform -chdir=terraform/environments/production output -raw zone_id 2>/dev/null || true)"
if [ -n "$ZONE_ID" ]; then
  python3 scripts/route53_cleanup.py "$ZONE_ID" --apply || true
fi

# These buckets stay in the account. prevent_destroy would stop the destroy.
for address in \
  module.storage.aws_s3_bucket.kops_state \
  module.storage.aws_s3_bucket_versioning.kops_state \
  module.storage.aws_s3_bucket_server_side_encryption_configuration.kops_state \
  module.storage.aws_s3_bucket_public_access_block.kops_state \
  module.storage.aws_s3_bucket.discovery \
  module.storage.aws_s3_bucket_public_access_block.discovery \
  module.storage.aws_s3_bucket_policy.discovery
do
  terraform -chdir=terraform/environments/production state rm "$address" || true
done

terraform -chdir=terraform/environments/production destroy -var install_platform=false

echo "Kept s3://kops-state-607, s3://agribridge-oidc-237258628535, and the Terraform state bucket."
echo "Delete the state bucket only after you no longer need the state:"
echo "  aws s3 rb s3://agribridge-tfstate-ACCOUNT_ID --force"
