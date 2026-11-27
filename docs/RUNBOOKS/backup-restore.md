# Backup and restore

Production installs a CronJob that runs `pg_dump` at 02:15 UTC and uploads the
file to `s3://agribridge-backups-237258628535/production/`. A copy is also
written to `production/latest.sql`. Objects expire after 30 days.

Show a backup and a restore:

```sh
./scripts/demo-backup-restore.sh agribridge-production
```

The script writes a marker row, takes a backup, changes the row, restores
`production/latest.sql`, and checks the marker is back to the dumped value.
It pauses Argo CD auto-sync, scales the API to 0 for the restore, scales it
back, and turns prune and selfHeal back on. Without that pause, selfHeal
would scale the API up in the middle of the restore.

Restore a named dump:

```sh
./scripts/restore-postgres.sh agribridge-production production/20261121T021500Z.sql
```

Take a backup without waiting for 02:15:

```sh
kubectl -n agribridge-production create job agribridge-backup-now \
  --from=cronjob/agribridge-postgres-backup
kubectl -n agribridge-production wait --for=condition=complete job/agribridge-backup-now --timeout=10m
```
