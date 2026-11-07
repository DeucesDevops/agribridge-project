# Argo CD installation plan reviewed — 2 November 2026

Status: Bernard applied the reviewed plan successfully: 2 added, 0 changed,
0 destroyed. Argo CD completed in 1m6s and bootstrap in 2s. Both releases are
deployed, all five reported Argo pods are ready and the refreshed platform plan
reports no changes. Source publication is a separate
approval; no Git commit, push or application rollout has occurred.

## Evidence and saved artifact

The supplied full verification transcript, Pasted text(20261102-144829).txt
(Library ID libfile_15ef974057088191aa33c6d3117c3c1e), confirms both image builds,
healthy Compose services, same-origin authentication and build identity, all
28 PostgreSQL integration tests, Redis degradation/recovery, database restart
and replacement persistence, and complete test cleanup. This resolves the
previous pending changed-image acceptance check.

The same transcript confirms pinned Argo CD chart rendering, core controller
readiness, services No changes, successful provider initialization/validation
and the saved plan:

- Artifact: .runtime/platform-20261102T144715Z-36783.tfplan.
- Readable output: .runtime/platform-20261102T144715Z-36783.txt.
- SHA-256: dfa2d7afe7f6a17fe37bb6e579a34b76dc000e042dacb57334c192a73edce6e3.
- **2 additions, 0 changes, 0 deletions**; no warnings in the readable plan.
- Embedded Terraform configuration matches current root/module sources.
- Local bootstrap-chart and Argo configuration fingerprints are saved privately
  alongside the plan for checking before apply.

## Exact scope

| Addition | Purpose |
|---|---|
| module.platform.helm_release.argocd[0] | Install upstream argo-cd chart 10.11.6, Argo CD v3.5.6, in namespace argocd |
| module.platform.helm_release.argocd_bootstrap[0] | Install local chart 0.1.0 after the controller, creating the reviewed AppProject and two Applications |

Existing platform Helm releases, namespaces, DNS and storage are unchanged.
The upstream render has only private ClusterIP services, no Ingress, PVC or
volume claim templates. This plan requests no additional EC2 group, public
load balancer, public IPv4 service or EBS volume. Existing AWS running charges
continue; controller activity still uses the current nodes and ordinary services.

The AppProject permits only this repository, selected application resource kinds
and the two existing environment namespaces. It permits no cluster-scoped
application resources. Applications track main with self-heal and automatic
pruning disabled; deletion finalizers cascade workloads on explicit removal.
The default direct-CI token/deploy-secret resources stay disabled.

The current published main branch does not contain helm/agribridge/Chart.yaml
(confirmed through GitHub's contents API). Application comparison may therefore
show a missing source path after controller/bootstrap installation until the
reviewed source is pushed. Do not repair the definitions by hand. The local
environment files keep releaseEnabled false until CI publishes verified images.

Publishing source later starts the reviewed CI/CD flow. It updates staging
digests, verifies HTTPS/readiness/build identity, and promotes the same digests
to production. The current production environment has no required-reviewer rule,
so promotion is automatic after staging succeeds. That publication decision
must cover both deployments and their two 20 GiB database volumes (40 GiB total,
about $3.20/month at the previously verified gp3 rate, before other usage/taxes).
Those application volumes are not created by this installation plan.

## Applied artifact

The following saved artifact was applied from the normal terminal:

```sh
terraform -chdir=terraform/platform apply -input=false \
  "$PWD/.runtime/platform-20261102T144715Z-36783.tfplan"
```

No extra variable file is needed for a saved apply. Do not change the local
bootstrap chart or substitute another artifact without review.

After completion, inspect the two releases and controller workloads, then check
a fresh no-change platform plan using .runtime/platform.tfvars.json. Application
source reconciliation errors before publication are distinct from controller
readiness. Review the complete source diff and obtain commit/push approval
before starting the new workflow.
