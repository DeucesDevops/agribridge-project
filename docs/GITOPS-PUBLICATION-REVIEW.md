# GitOps source publication review — 2 November 2026

Status: prepared locally; no commit, push or workflow dispatch performed.
Argo CD and its bootstrap release were applied successfully with 2 additions,
0 changes and 0 deletions. Bernard's follow-up output confirms both releases
deployed, all five reported Argo pods ready with zero restarts, and a refreshed
platform plan with no changes. Both Applications report Unknown sync / Healthy;
this does not establish application deployment. The unpublished chart path is
the expected source blocker, but Application condition messages were not supplied.

## Proposed publication

- Repository: DeucesDevops/agribridge-project, branch main.
- Suggested commit: Implement staged Terraform rebuild and Argo CD GitOps.
- Include the coherent source changes and earlier folder moves: web to frontend,
  charts to helm, infra to Terraform entry points/modules, cluster source to
  kubedefs, and compose.yaml to docker-compose.yml.
- Include delivery workflow, release helpers, application Helm chart, Argo
  controller/bootstrap configuration, metadata-only environment values,
  Terraform sources/lockfiles and supporting documentation.
- Remove the former tracked generated cluster output. Regeneration remains
  local and ignored; do not publish the current generated AWS objects.
- Exclude runtime files, environment credentials, state/plans, kubeconfig,
  dependencies and test reports. Leave the roadmap/generated image artifacts
  outside this publication.

The exact candidate paths and SHA-256 fingerprints are recorded privately in
.runtime/publication-manifest.json. A matching NUL-separated path list is in
.runtime/publication-paths.nul. These describe the reviewed candidate; they do
not stage or commit files. Recheck fingerprints and review changes before use.

## Effect of pushing main

GitHub Actions runs checks, builds and verifies both images, scans them, and
publishes to Docker Hub. It commits the resulting immutable digests for staging.
Argo CD reconciles staging; HTTPS readiness and build identity must pass before
production receives the same digests. The production GitHub environment has no
required-reviewer rule, so production promotion is automatic after staging passes.
CI updates only the fixed environment image-values paths and uses no AWS keys
or Kubernetes credentials.

Both environments will request a 20 GiB database volume: 40 GiB total, about
$3.20/month at the previously verified gp3 rate, before other usage and taxes.
Existing AWS charges continue. The controller installation itself requested no
additional EC2 group, public load balancer or EBS volume.

## Evidence and remaining checks

Thirteen release/render tests passed. Both charts linted; shell/Python/workflow
syntax, Terraform formatting and whitespace checks passed. The full supplied
local image acceptance transcript confirms healthy services, authentication,
build identity, all 28 integration tests, Redis recovery, database persistence
and cleanup. GitHub authentication, Actions availability, push permission and
Docker Hub secret-name presence were checked. Basic credential-format screening
found no matching live credentials in the candidate files; this is not a full
security audit.

Docker Hub authentication, actual image scans/publication, the first workflow,
Argo sync/health, application secret delivery, migrations and HTTPS acceptance
remain unverified until the live run. Complete Git-based rollback evidence
before marking stage 6 complete.

Source publication requires Bernard's explicit commit/push approval under the
[session agreement](REBUILD-SESSION.md). Approval of the Terraform controller
apply does not authorize publication or the resulting application rollout.
