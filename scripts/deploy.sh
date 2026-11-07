#!/usr/bin/env bash
# Legacy entry point retained to explain the GitOps ownership change.
set -euo pipefail
printf '%s\n' 'Direct Helm application deployment has been retired.' 'Follow argocd/README.md; CI updates Git and Argo CD owns application releases.' >&2
exit 2
