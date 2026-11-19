#!/usr/bin/env bash
# Show that a dump can be restored.
# Inserts a marker, takes a backup, changes the marker, restores, and checks
# the marker is back to the backed-up value.
# Usage: scripts/demo-backup-restore.sh [namespace]
set -euo pipefail

NS="${1:-agribridge-production}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PSQL=(kubectl -n "$NS" exec agribridge-postgres-0 -- psql -U agribridge -d agribridge -v ON_ERROR_STOP=1)

echo "This replaces the database in ${NS} with a dump taken a moment earlier."
"${PSQL[@]}" -c "CREATE TABLE IF NOT EXISTS backup_demo (note text); DELETE FROM backup_demo; INSERT INTO backup_demo (note) VALUES ('before-backup');"

JOB="agribridge-backup-demo-$(date +%s)"
kubectl -n "$NS" create job "$JOB" --from=cronjob/agribridge-postgres-backup
if ! kubectl -n "$NS" wait --for=condition=complete "job/${JOB}" --timeout=10m; then
  kubectl -n "$NS" logs "job/${JOB}" --all-containers || true
  exit 1
fi

"${PSQL[@]}" -c "UPDATE backup_demo SET note = 'after-backup';"
"$ROOT/scripts/restore-postgres.sh" "$NS"

note="$("${PSQL[@]}" -tAc "SELECT note FROM backup_demo;")"
echo "backup_demo.note is '${note}'."
if [ "$note" != "before-backup" ]; then
  echo "Expected before-backup. The restore did not return the dumped row."
  exit 1
fi
echo "Restore brought the marker row back. The dump is usable."
