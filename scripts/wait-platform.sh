#!/usr/bin/env bash
# Readiness gate for kOps-managed dependencies; never changes the cluster.
set -euo pipefail
kubectl wait --for=condition=Ready nodes --all --timeout=900s
for deployment in aws-load-balancer-controller pod-identity-webhook ebs-csi-controller; do
  kubectl -n kube-system rollout status "deployment/$deployment" --timeout=900s
done
# Check actual ready addresses as well as the controller rollout.
for service in aws-load-balancer-webhook-service pod-identity-webhook; do
  ready=false
  for ((attempt=0; attempt<90; attempt++)); do
    addresses=$(kubectl -n kube-system get endpointslices \
      -l "kubernetes.io/service-name=$service" \
      -o 'jsonpath={range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[*]}{end}')
    if [ -n "$addresses" ]; then ready=true; break; fi
    sleep 5
  done
  if [ "$ready" != true ]; then
    echo "Admission service $service has no ready endpoints" >&2
    exit 1
  fi
done
