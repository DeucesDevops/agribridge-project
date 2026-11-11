# GitOps runbook

## Install

Run the infrastructure workflow's bootstrap, cluster, services and platform stages
in order. Services application publishes current non-secret references to these
values files. Platform application installs the controller and bootstrap chart
with Argo CD enabled. See [reproduction](../docs/REPRODUCTION.md).

The controller stays private. It watches `main` and renders the same application
chart with environment behavior first, then environment runtime/release values.
There is one application owner: Argo CD. Do not run a parallel `helm upgrade`.

## Release

1. Delivery checks must pass, including real PostgreSQL integration tests.
2. Publish the exact images exercised in CI and record their registry digests.
3. Commit those digests into staging values.
4. Argo CD reconciles; public HTTPS, readiness and version checks verify the release.
5. Promote the same digests to production and verify again. Environment protection
   can deliberately pause production if a reviewer is configured.

Actions' Git writes fail on concurrent changes rather than force-pushing. If a
release fails after staging, inspect that run and the desired Git values before
rerunning; do not rebuild an artifact solely to promote it.

## Inspect

With an authorized cluster session:

```sh
kubectl -n argocd get applications
kubectl -n agribridge-staging get pods,externalsecrets,pvc
kubectl -n agribridge-production get pods,externalsecrets,pvc
```

Dispatch `operations.yaml`, `task=check`, for each environment to verify public and
runtime acceptance. Image references must be immutable digests; `/version` must
identify their source commit and run tag. Readiness must distinguish a missing
cache from a missing database.

## Roll back and remove

Rollback changes the desired image digests in Git. Assess schema compatibility;
Argo CD does not reverse database migrations. The Applications use resource
finalizers, so delete them while the controller is still running when deliberately
decommissioning the environment. PostgreSQL claims and retained EBS data need
separate backup and deletion decisions. Follow [operations](../docs/OPERATIONS.md).

Historical [installation](../docs/evidence/PLAN-REVIEW.md) and
[rollback](../docs/evidence/ROLLBACK-REVIEW.md) reviews describe the earlier live
system. They do not prove the new workflow implementation has executed.
