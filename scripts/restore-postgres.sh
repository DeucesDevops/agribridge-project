#!/usr/bin/env bash
# Replace one environment's database with a dump from the backup bucket.
# Usage: scripts/restore-postgres.sh [namespace] [s3-key]
# The key defaults to <prefix>/latest.sql from the backup CronJob.
set -euo pipefail

NS="${1:-agribridge-production}"
KEY="${2:-}"
CRON="agribridge-postgres-backup"

kubectl -n "$NS" get cronjob "$CRON" >/dev/null

jsonpath() {
  kubectl -n "$NS" get cronjob "$CRON" -o "jsonpath=$1"
}

BUCKET="$(jsonpath '{.spec.jobTemplate.spec.template.spec.containers[0].env[?(@.name=="BUCKET")].value}')"
PREFIX="$(jsonpath '{.spec.jobTemplate.spec.template.spec.containers[0].env[?(@.name=="PREFIX")].value}')"
AWS_IMAGE="$(jsonpath '{.spec.jobTemplate.spec.template.spec.containers[0].image}')"
PG_IMAGE="$(jsonpath '{.spec.jobTemplate.spec.template.spec.initContainers[0].image}')"

if [ -z "$BUCKET" ] || [ -z "$PREFIX" ]; then
  echo "The backup CronJob has no bucket or prefix. Deploy with the BACKUP_BUCKET and backup role Terraform publishes."
  exit 1
fi
if [ -z "$KEY" ]; then
  KEY="${PREFIX}/latest.sql"
fi

REPLICAS="$(kubectl -n "$NS" get deploy agribridge-api -o jsonpath='{.spec.replicas}')"
ARGO_APP_NS="${ARGO_APP_NS:-argocd}"
ARGO_APP="${ARGO_APP:-agribridge}"
PAUSED=0
resume_api() {
  if [ "$PAUSED" = "1" ]; then
    # Put automated sync back before anything else reads the Application.
    # Terraform owns this object. The patch restores the same prune and selfHeal values.
    kubectl -n "$ARGO_APP_NS" patch application "$ARGO_APP" --type merge \
      -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' || true
  fi
  kubectl -n "$NS" scale deploy agribridge-api --replicas="$REPLICAS"
}
trap resume_api EXIT

if kubectl -n "$ARGO_APP_NS" get application "$ARGO_APP" -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null | grep -q true; then
  echo "Pausing Argo CD auto-sync so selfHeal does not scale the API back up during the restore."
  kubectl -n "$ARGO_APP_NS" patch application "$ARGO_APP" --type json \
    -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
  PAUSED=1
fi

echo "Scaling agribridge-api to 0 in ${NS} before the restore."
kubectl -n "$NS" scale deploy agribridge-api --replicas=0
kubectl -n "$NS" rollout status deploy/agribridge-api --timeout=180s

JOB="agribridge-postgres-restore-$(date +%s)"
kubectl -n "$NS" apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB}
spec:
  backoffLimit: 1
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      serviceAccountName: agribridge-backup
      automountServiceAccountToken: true
      restartPolicy: Never
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      initContainers:
        - name: download
          image: ${AWS_IMAGE}
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          command: ["sh", "-c"]
          args:
            - |
              set -eu
              aws s3 cp "s3://${BUCKET}/${KEY}" /backup/dump.sql
              test -s /backup/dump.sql
          env:
            - name: HOME
              value: /tmp
          volumeMounts:
            - name: dump
              mountPath: /backup
            - name: tmp
              mountPath: /tmp
      containers:
        - name: restore
          image: ${PG_IMAGE}
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            runAsUser: 999
            runAsGroup: 999
            capabilities:
              drop: ["ALL"]
          command: ["sh", "-c"]
          args:
            - |
              set -eu
              psql --host "\$PGHOST" --username "\$PGUSER" --dbname "\$PGDATABASE" -v ON_ERROR_STOP=1 \
                -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();"
              psql --host "\$PGHOST" --username "\$PGUSER" --dbname "\$PGDATABASE" -v ON_ERROR_STOP=1 \
                -f /backup/dump.sql
          env:
            - name: PGHOST
              value: agribridge-postgres-0.agribridge-postgres
            - name: PGUSER
              value: agribridge
            - name: PGDATABASE
              value: agribridge
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: agribridge-runtime
                  key: PGPASSWORD
          volumeMounts:
            - name: dump
              mountPath: /backup
      volumes:
        - name: dump
          emptyDir: {}
        - name: tmp
          emptyDir: {}
EOF

echo "Restoring s3://${BUCKET}/${KEY} into ${NS}."
if ! kubectl -n "$NS" wait --for=condition=complete "job/${JOB}" --timeout=10m; then
  kubectl -n "$NS" logs "job/${JOB}" --all-containers || true
  exit 1
fi
echo "Restore finished. The API is scaled back to ${REPLICAS}."
