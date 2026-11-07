# Operations

Cloud operations run through `operations.yaml`, dispatched from `main`. They use
a dedicated runner and short-lived AWS/kOps credentials. Setup is described in
[CONFIGURATION.md](CONFIGURATION.md). No task needs SSH access to a node.

## Check a release

Select `task=check` and `environment=staging` or `production`. The job waits for
External Secrets and workloads, lists persistent claims, checks public HTTPS and
build identity, and verifies runtime secret presence, migrations and staging login
without printing credentials.

```sh
gh workflow run operations.yaml --ref main -f task=check -f environment=staging
```

## Back up and test a restore

The Helm-managed backup CronJob runs daily at 02:00 according to the cluster
controller's timezone. It writes PostgreSQL custom-format dumps to each
environment's prefix in the private backup bucket. A manual `task=backup` run
creates a Job from that same CronJob, waits for completion and removes the Job.

Find the resulting object's key using an authorized S3 listing, then select
`task=restore-test` with that key and the matching environment:

```sh
gh workflow run operations.yaml --ref main \
  -f task=restore-test -f environment=staging \
  -f backup_key=staging/2026-11-01T02-00-00Z.dump
```

The workflow renders only `helm/agribridge/templates/restore-test.yaml`. The Job
downloads the selected backup with the workload's backup IAM identity, initializes
PostgreSQL in an `emptyDir`, restores into `restore_check`, checks the application's
tables and migration history, and exits. It creates no Service, uses no live
database PVC and never connects to the application database. Local trust
authentication is limited to that temporary PostgreSQL process; no production
password is needed. The workflow deletes the Job and its temporary storage.

This verifies that a dump can be restored and queried. It does not demonstrate a
production failover or point-in-time recovery. Restoring data into the live
database requires a separate, reviewed recovery procedure.

## Demonstrate resilience

Select `task=staging-resilience`, `environment=staging`. The task restarts the
staging Redis pod and observes degraded readiness, database fallback and cache
recovery. It replaces the staging PostgreSQL pod and compares the existing claim,
volume and table fingerprints. It deliberately interrupts staging; production is
rejected by the workflow. Non-secret JSON evidence is uploaded as an Actions
artifact before private runner files are removed.

## Roll back

Inspect the desired environment's release commit, then revert the relevant
`argocd/<environment>-values.yaml` change in Git. Do not rebuild or retag the old
images. Argo CD reconciles the previous digests. Run `task=check` afterward.
If schema migrations are incompatible with the older application, assess database
compatibility before selecting the older release; image rollback does not roll
back the database schema.

## Access monitoring

Use an authorized kubeconfig for `k8s.agribridge.deuces.dev`. Prometheus, Grafana
and Argo CD stay private. Port-forward the appropriate service from your machine:

```sh
kubectl -n monitoring get services
kubectl -n monitoring port-forward svc/monitoring-grafana 3001:80
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

Retrieve the Grafana admin credential through authorized Kubernetes access;
never paste it into reports or pipeline logs. Useful API metrics include HTTP
rate/latency, database pool activity, cache outcomes and build information. See
`helm/agribridge/templates/monitoring.yaml` for scrape targets and alert rules.

## Decommission before destroying infrastructure

Infrastructure destruction is an explicit manual request. `bootstrap` destruction
is refused. Platform destruction is refused while application workloads or PVCs
remain; cluster/services destruction is refused while platform state still owns
managed resources.

1. Stop application releases. Back up each environment and verify its restore.
2. With an authorized cluster session, delete the two Argo CD Applications while
   Argo CD is still running. Their existing resource finalizers remove tracked
   application resources. Confirm deletion completes before removing controllers:

   ```sh
   kubectl -n argocd delete application agribridge-staging agribridge-production --wait=true --timeout=15m
   ```

3. Inspect the two namespaces. PostgreSQL StatefulSet claims are deliberately
   retained; delete those claims only after explicitly approving loss of their
   live data. The StorageClass uses `Retain`, so deleting a PVC alone does not
   delete its retained EBS volume. Inventory and remove those volumes separately
   after backup verification when ending the environment permanently.
4. Dispatch `infrastructure.yaml` with `stage=platform`, `action=destroy` and
   `confirmation=k8s.agribridge.deuces.dev`. Review its private plan and approve
   the protected environment. Controllers remain available for cleanup until this
   stage completes.
5. Dispatch the same workflow for `stage=cluster`, `action=destroy`. Retain services
   if keeping backups, secrets and recovery resources. For a full cleanup, services
   can be removed after platform teardown, but Terraform deliberately refuses to
   destroy a non-empty backup bucket. Inventory retained storage and data first.
6. Verify EC2 instances, load balancers and chargeable EBS volumes are gone.
   Keep the state/kOps buckets and project DNS for recovery unless separately
   authorizing their deletion. Retained DNS, secrets and storage can still incur costs.

The refactor itself runs none of these cloud actions. Partial infrastructure
failures should be resolved by reviewing state and rerunning the relevant stage,
never by deleting state to force a fresh creation.
