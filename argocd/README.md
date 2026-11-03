# Argo CD GitOps

Stage 6 is complete. Argo CD and its bootstrap release
were installed on 2 November 2026. All reported Argo pods are ready and the
refreshed platform plan reports no changes. Source is published and workflow
41470632352 and 41473944213 passed all four jobs. Both environments respond over HTTPS with
healthy readiness checks and the same build; their Git values pin identical
published image digests. Detailed runtime acceptance passed in both environments;
A Git-based rollback returned staging to the first verified images, then restored
the second release. Both Applications are Synced/Healthy and both original database
claims remain bound. See [the rollback evidence](ROLLBACK-REVIEW.md).

Terraform installed the controller and the bootstrap Helm release containing
project.yaml and both Application definitions. GitHub Actions will test, scan
and publish images, then commit their immutable digests for Argo CD to deploy
using helm/agribridge. Production receives staging's verified digests.

The local workflow's direct Helm deployment path has been replaced. The version
on GitHub remains unchanged until the reviewed source is published.

Follow [GITOPS-RUNBOOK.md](GITOPS-RUNBOOK.md) for checks, planning, publication
effects, bootstrap and live acceptance. Runtime secret values stay in AWS Secrets
Manager and are delivered by External Secrets; no credentials belong here.
