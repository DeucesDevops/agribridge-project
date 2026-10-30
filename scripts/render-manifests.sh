#!/usr/bin/env bash
# Produce a flat, reviewable manifest from the chart and Terraform handoff.
set -euo pipefail
cd "$(dirname "$0")/.."
environment=${1:?usage: render-manifests.sh staging|production image-tag}
image_tag=${2:?image tag required}
case "$environment" in staging|production) ;; *) exit 2 ;; esac
umask 077
runtime=$(mktemp -d)
trap 'rm -rf "$runtime"' EXIT
aws ssm get-parameter --region us-east-1 --name "/agribridge/$environment/deployment" \
  --query Parameter.Value --output text > "$runtime/deployment.json"
jq --arg tag "$image_tag" --arg environment "$environment" '{
  hostname, region, secretArn: .secret_arn,
  api: {repository: .api_repository, tag: $tag},
  web: {repository: .web_repository, tag: $tag},
  backup: {bucket: .backup_bucket, role: .backup_role, prefix: $environment}
}' "$runtime/deployment.json" > "$runtime/values.json"
namespace=$(jq -r .namespace "$runtime/deployment.json")
printf 'apiVersion: v1\nkind: Namespace\nmetadata:\n  name: %s\n---\n' "$namespace" > "$runtime/rendered.yaml"
helm template agribridge helm/agribridge --namespace "$namespace" \
  --values "helm/agribridge/values-$environment.yaml" --values "$runtime/values.json" >> "$runtime/rendered.yaml"
mv "$runtime/rendered.yaml" "kops/$environment-rendered.yaml"
echo "Rendered kops/$environment-rendered.yaml"
