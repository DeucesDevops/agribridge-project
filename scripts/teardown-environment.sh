#!/usr/bin/env bash
# Remove the environment. A plain terraform destroy is the wrong first command:
# the application Ingress is not in Terraform, and ExternalDNS does not delete
# the records it created. This script does those steps, then destroys the root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REGION="${AWS_REGION:-us-east-1}"
CLUSTER="${CLUSTER_NAME:-agribridge}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Export GITHUB_TOKEN. Terraform removes the Actions variables and environments it created."
  exit 1
fi

if aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  helm uninstall agribridge --namespace agribridge-qa || true
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
  terraform -chdir=terraform destroy -var install_platform=true -target=module.platform
else
  echo "The cluster API did not answer. Skipping the Helm uninstall."
  echo "If destroy then stops on the platform module, run: terraform -chdir=terraform state rm 'module.platform'"
fi

ZONE_ID="$(terraform -chdir=terraform output -raw zone_id 2>/dev/null || true)"
if [ -n "$ZONE_ID" ]; then
  python3 scripts/route53_cleanup.py "$ZONE_ID" --apply
fi

# install_platform stays false here so Terraform does not need the API again.
terraform -chdir=terraform destroy -var install_platform=false

echo "Terraform state bucket was kept. Empty and delete it only after you have downloaded anything you still need:"
echo "  aws s3 rb s3://agribridge-tfstate-ACCOUNT_ID --force"
echo "The old kops-state-607 and agribridge-oidc-237258628535 buckets, if you still have them, are not in Terraform."
