# Argo CD GitOps

Stage 6 source is prepared and tested locally. Argo CD and its bootstrap release
were installed on 2 November 2026. All reported Argo pods are ready and the
refreshed platform plan reports no changes. Source publication and the first
application workflow run remain pending.

Terraform installed the controller and the bootstrap Helm release containing
project.yaml and both Application definitions. GitHub Actions will test, scan
and publish images, then commit their immutable digests for Argo CD to deploy
using helm/agribridge. Production receives staging's verified digests.

The local workflow's direct Helm deployment path has been replaced. The version
on GitHub remains unchanged until the reviewed source is published.

Follow [GITOPS-RUNBOOK.md](GITOPS-RUNBOOK.md) for checks, planning, publication
effects, bootstrap and live acceptance. Runtime secret values stay in AWS Secrets
Manager and are delivered by External Secrets; no credentials belong here.
