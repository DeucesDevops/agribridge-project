#!/usr/bin/env bash
set -euo pipefail
# Non-secret runtime configuration is published by Terraform, never copied by hand.
environment=${1:?usage: deploy.sh staging|production image-tag}
image_tag=${2:?image tag required}
case "$environment" in staging|production) ;; *) exit 2 ;; esac
umask 077
runtime=$(mktemp -d)
trap 'rm -rf "$runtime"' EXIT
aws ssm get-parameter --region us-east-1 --name "/agribridge/$environment/deployment" --query Parameter.Value --output text > "$runtime/deployment.json"
aws secretsmanager get-secret-value --region us-east-1 --secret-id "$(jq -r .deploy_secret "$runtime/deployment.json")" --query SecretString --output text > "$runtime/kubeconfig"
export KUBECONFIG="$runtime/kubeconfig"
jq --arg tag "$image_tag" --arg environment "$environment" '{
  hostname, region, secretArn: .secret_arn,
  api: {repository: .api_repository, tag: $tag},
  web: {repository: .web_repository, tag: $tag},
  backup: {bucket: .backup_bucket, role: .backup_role, prefix: $environment}
}' "$runtime/deployment.json" > "$runtime/values.json"
namespace=$(jq -r .namespace "$runtime/deployment.json")
helm upgrade --install agribridge helm/agribridge --namespace "$namespace" \
  --values "helm/agribridge/values-$environment.yaml" --values "$runtime/values.json" \
  --atomic --timeout 15m --history-max 10
kubectl -n "$namespace" rollout status deployment/agribridge-api --timeout=180s
kubectl -n "$namespace" exec deployment/agribridge-api -- node -e \
  "fetch('http://localhost:3000/version').then(r=>{if(!r.ok)throw new Error('Version endpoint failed');return r.json()}).then(v=>{if(v.imageTag!==process.argv[1])throw new Error('Deployed image tag does not match requested release');console.log(JSON.stringify(v))}).catch(e=>{console.error(e.message);process.exit(1)})" "$image_tag"
curl --fail --silent --show-error --retry 12 --retry-delay 5 --retry-all-errors "https://$(jq -r .hostname "$runtime/deployment.json")/" -o /dev/null
