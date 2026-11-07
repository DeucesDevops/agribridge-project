#!/usr/bin/env bash
# Prepare runtime references and plan the Argo CD controller/bootstrap releases.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .runtime
mkdir -p .runtime/helm-cache .runtime/helm-config .runtime/helm-data
bash scripts/prepare-gitops.sh
# Render the pinned upstream chart before any infrastructure apply. Rendered
# generated Secret objects stay private; never print or commit this file.
HELM_CACHE_HOME="$PWD/.runtime/helm-cache" HELM_CONFIG_HOME="$PWD/.runtime/helm-config" \
  HELM_DATA_HOME="$PWD/.runtime/helm-data" \
  helm template argocd argo-cd --repo https://argoproj.github.io/argo-helm \
  --version 10.11.6 --namespace argocd --values argocd/argocd-values.yaml \
  > .runtime/argocd-controller-rendered.yaml
python3 - <<'PY'
from pathlib import Path
import yaml
docs = [d for d in yaml.safe_load_all(Path('.runtime/argocd-controller-rendered.yaml').read_text()) if d]
services = [d for d in docs if d.get('kind') == 'Service']
assert any(d['metadata']['name'] == 'argocd-server' for d in services), 'Argo CD server Service is missing'
assert all(d['spec'].get('type', 'ClusterIP') == 'ClusterIP' for d in services), 'Unexpected public Argo CD service'
assert not any(d.get('kind') == 'Ingress' for d in docs), 'Unexpected public Argo CD ingress'
assert not any(d.get('kind') == 'PersistentVolumeClaim' for d in docs), 'Unexpected Argo CD storage charge'
assert not any(d.get('spec', {}).get('volumeClaimTemplates') for d in docs), 'Unexpected Argo CD storage claim template'
print('Pinned Argo CD chart rendered with private ClusterIP services.')
PY
AGRIBRIDGE_ENABLE_ARGOCD=true bash scripts/plan-platform.sh
