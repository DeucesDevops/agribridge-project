#!/usr/bin/env bash
set -euo pipefail
environment=${1:?usage: restore-drill.sh staging|production backup-object-key}
key=${2:?S3 object key required}
case "$environment" in staging|production) ;; *) exit 2 ;; esac
case "$key" in "$environment/"*.dump) ;; *) echo 'Backup key must belong to the selected environment' >&2; exit 2 ;; esac
namespace="agribridge-$environment"
name="restore-drill-$(date +%s)"
bucket=$(aws ssm get-parameter --region us-east-1 --name "/agribridge/$environment/deployment" --query Parameter.Value --output text | jq -r .backup_bucket)
trap 'kubectl -n "$namespace" delete pod "$name" --ignore-not-found --wait=false >/dev/null' EXIT
python3 - "$name" "$namespace" "$bucket" "$key" <<'PY' | kubectl apply -f -
import json, sys
name, namespace, bucket, key = sys.argv[1:]
print(json.dumps({
 'apiVersion':'v1', 'kind':'Pod', 'metadata':{'name':name,'namespace':namespace},
 'spec':{'serviceAccountName':'agribridge-backup', 'restartPolicy':'Never',
  'initContainers':[{'name':'download','image':'amazon/aws-cli:2.32.0',
   'args':['s3','cp',f's3://{bucket}/{key}','/backup/database.dump','--only-show-errors'],
   'volumeMounts':[{'name':'backup','mountPath':'/backup'}]}],
  'containers':[{'name':'postgres','image':'postgres:16.11-bookworm',
   'env':[{'name':'POSTGRES_DB','value':'restore_check'}, {'name':'POSTGRES_USER','value':'agribridge'},
    {'name':'POSTGRES_PASSWORD','valueFrom':{'secretKeyRef':{'name':'agribridge-runtime','key':'PGPASSWORD'}}}],
   'readinessProbe':{'exec':{'command':['pg_isready','-U','agribridge','-d','restore_check']},'periodSeconds':3},
   'volumeMounts':[{'name':'backup','mountPath':'/backup'},{'name':'data','mountPath':'/var/lib/postgresql/data'}],
   'resources':{'requests':{'cpu':'100m','memory':'256Mi'},'limits':{'memory':'1Gi'}}}],
  'volumes':[{'name':'backup','emptyDir':{}},{'name':'data','emptyDir':{}}]}}))
PY
kubectl -n "$namespace" wait --for=condition=Ready "pod/$name" --timeout=300s
kubectl -n "$namespace" exec "$name" -c postgres -- pg_restore --exit-on-error --no-owner -U agribridge -d restore_check /backup/database.dump
kubectl -n "$namespace" exec "$name" -c postgres -- psql -v ON_ERROR_STOP=1 -U agribridge -d restore_check -c \
  "SELECT 'users' AS entity, count(*) FROM users UNION ALL SELECT 'lots',count(*) FROM lots UNION ALL SELECT 'orders',count(*) FROM orders UNION ALL SELECT 'order_events',count(*) FROM order_events;"
echo 'Restore drill completed in isolated temporary storage; live database untouched.'
