# Operations

Run these commands from the repository root using the short-lived cluster session
created in [REPRODUCTION.md](REPRODUCTION.md). Check `kubectl config current-context`
is `k8s.agribridge.deuces.dev` before changing resources. Keep deployment disabled
and let any active Actions delivery finish during maintenance.

## Check a release

Select `staging` or `production`, then inspect secret readiness and rollouts:

```sh
export ENVIRONMENT=staging
export NAMESPACE=agribridge-$ENVIRONMENT
kubectl -n "$NAMESPACE" wait --for=condition=Ready externalsecret/agribridge --timeout=300s
kubectl -n "$NAMESPACE" rollout status statefulset/agribridge-postgres --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/agribridge-api --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/agribridge-web --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/agribridge-redis --timeout=300s
kubectl -n "$NAMESPACE" get pods,services,ingress,pvc
export RELEASE_TAG=$(python -c 'import os,yaml; print(yaml.safe_load(open("argocd/"+os.environ["ENVIRONMENT"]+"-values.yaml"))["api"]["tag"])')
python scripts/smoke-test.py "$ENVIRONMENT" "$RELEASE_TAG" --runtime
```

The smoke check verifies HTTPS, readiness, exact image identity, migrations and
runtime secret presence without printing credentials. Repeat for production.

## Back up

The Helm-managed CronJob runs daily at 02:00 in the cluster controller's timezone.
An on-demand backup uses that same job definition:

```sh
export BACKUP_JOB=agribridge-backup-$(date -u +%Y%m%d%H%M%S)
kubectl -n "$NAMESPACE" create job "$BACKUP_JOB" --from=cronjob/agribridge-backup
kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$BACKUP_JOB" --timeout=1800s
kubectl -n "$NAMESPACE" logs "job/$BACKUP_JOB" -c upload
```

Check completion and the uploaded S3 key before removing the completed Job with
`kubectl -n "$NAMESPACE" delete job "$BACKUP_JOB"`. On failure, inspect the Job
and its pods before cleanup. Dumps remain in the private backup bucket.

## Test a restore in temporary storage

Select an existing dump from the matching environment's S3 prefix. Substitute
its actual key below:

```sh
export BACKUP_KEY=staging/2026-11-01T02-00-00Z.dump
export RESTORE_JOB=agribridge-restore-$(date -u +%Y%m%d%H%M%S)
helm template agribridge helm/agribridge -n "$NAMESPACE" \
  -f "helm/agribridge/values-$ENVIRONMENT.yaml" \
  -f "argocd/$ENVIRONMENT-values.yaml" \
  --set restoreTest.enabled=true --set-string restoreTest.jobName="$RESTORE_JOB" \
  --set-string restoreTest.key="$BACKUP_KEY" \
  --show-only templates/restore-test.yaml > .runtime/restore-job.yaml
kubectl -n "$NAMESPACE" create -f .runtime/restore-job.yaml
kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$RESTORE_JOB" --timeout=1800s
kubectl -n "$NAMESPACE" logs "job/$RESTORE_JOB" -c verify
```

Helm rejects a backup key from another environment. The Job restores into a
temporary PostgreSQL database on `emptyDir`, checks tables and migration history,
and never mounts the live database PVC or connects to the app database. Delete
the completed Job after inspecting the result. Its TTL also removes it after an
hour. This tests backup readability, not production failover or point-in-time recovery.

## Demonstrate staging resilience

```sh
python scripts/check-resilience.py
```

Run deliberately: this interrupts **staging** Redis and PostgreSQL pods, verifies
cache fallback/recovery and persistent data, and writes non-secret evidence under
`.runtime/automation/resilience/`. It never selects production.

## Monitoring

Grafana, Prometheus and Argo CD stay private. Run each port-forward in a separate
terminal on your workstation with authorized cluster access:

```sh
kubectl -n monitoring port-forward svc/monitoring-grafana 3001:80
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

Open http://localhost:3001, http://localhost:9090 and https://localhost:8081 as
appropriate. A port-forward on the management server binds to that server, not
your laptop. Retrieve admin credentials privately through authorized Kubernetes
access. API metrics and alerts are in `helm/agribridge/templates/monitoring.yaml`;
Fluent Bit sends application logs to CloudWatch.

## Roll back

Revert the relevant `argocd/<environment>-values.yaml` image selection on `dev`,
then use the checked PR to `main` flow. Argo CD reconciles the previous published
digests. Do not rebuild or retag them. Assess schema compatibility first: image
rollback does not reverse migrations. Re-run the health checks afterward.

## Tear down in reverse order

Teardown is a separate deliberate operation. Disable `DEPLOY_ENABLED`, wait for
active delivery to finish, back up both environments and verify restoration.

1. Delete the Argo CD Applications **while Argo CD is still running**:

   ```sh
   kubectl -n argocd delete application agribridge-staging agribridge-production --wait=true --timeout=15m
   ```

2. Inspect both namespaces for remaining Deployments, StatefulSets, Jobs, CronJobs,
   Services, ingresses and PVCs. PostgreSQL claims are retained. Delete live data
   only when its loss is explicitly authorized. `Retain` EBS volumes need a separate
   inventory and deletion decision even after their claims are removed.
3. Plan platform destruction using the **same current backend and input file**:

   ```sh
   terraform -chdir=terraform/platform plan -destroy \
     -var-file=../../.runtime/platform.tfvars.json -out=../../.runtime/platform-destroy.tfplan
   ```

   Review and apply that saved plan. Wait for ingress/load-balancer cleanup. Do
   not destroy the cluster while platform state still owns managed resources.
4. Generate missing cluster input with `prepare-cluster.py generate --destroy`
   against the retained kOps store if necessary. Plan and review cluster destruction
   with its existing backend, then apply the saved plan:

   ```sh
   terraform -chdir=terraform/cluster plan -destroy -out=../../.runtime/cluster-destroy.tfplan
   terraform -chdir=terraform/cluster apply ../../.runtime/cluster-destroy.tfplan
   ```

5. Retain services if keeping secrets, backups and recovery resources. A full
   services teardown requires a separate reviewed plan. Terraform refuses to
   destroy a non-empty backup bucket; never empty it just to bypass that guard.
6. Verify EC2 instances, load balancers and chargeable EBS volumes. Keep bootstrap
   state/kOps buckets and DNS for recovery. Retained DNS, secrets and storage can
   still incur costs. Stop the management host when it is no longer needed.

Never delete state to force a fresh deployment. Resolve partial failures through
resource inspection, current state and a new reviewed plan.
