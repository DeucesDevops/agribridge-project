# Operational acceptance results

This summary records the completed AWS demonstration from **2 November 2026**.
It was prepared from the saved cache-resilience, database-persistence and
staging/production restore receipts. It introduces no new live test claim.

## Cache resilience

The staging Redis pod was restarted. The recorded observations show:

| Phase | Readiness HTTP status | Degraded flag |
|---|---|---|
| Healthy baseline | 200 | false |
| Cache unavailable | 200 | true |
| Cache recovered | 200 | false |

The receipt records a passing result for degradation and recovery. Redis loss
was observable without making the otherwise usable API unavailable.

## Database persistence

The staging PostgreSQL pod was replaced. Its old and new pod UIDs differ, and
the before/after table fingerprints match for `users`, `lots`, `orders`,
`order_events` and `schema_migrations`. The receipt records the persistent claim
and volume identity and a passing persistence result.

## Backup restoration

Backups dated 2 November were restored into isolated temporary PostgreSQL storage.
Both restore receipts record `passed=true` and `live_database_modified=false`.
The restore storage was `emptyDir`; no additional EBS volume was used.

| Table | Staging restored rows | Production restored rows |
|---|---|---|
| `users` | 9 | 0 |
| `lots` | 8 | 0 |
| `orders` | 6 | 0 |
| `order_events` | 6 | 0 |
| `schema_migrations` | 1 | 1 |

Staging's restored table fingerprints match the saved pre-restore database
baseline. Production was deliberately unseeded; its restore contains the applied
migration and no demonstration accounts or marketplace records.

These results demonstrate persistent data and queryable backup recovery. They do
not demonstrate point-in-time recovery, automatic failover or restoration into
the live production database.

## Other evidence

- [Successful staging/production delivery](https://github.com/DeucesDevops/agribridge-project/actions/runs/41473944213)
- [Git-based rollback and release restoration](ROLLBACK-REVIEW.md)
- [Metrics, log collection and internal alert demonstration](STAGE7-REVIEW.md)
- [Current validation scope](../VERIFICATION.md)

This is a sanitized summary of the preserved receipts. It contains no credentials,
customer data, database contents, state files or kubeconfig material. Raw local
receipts are not included in the public submission. The later workflow refactor
still requires separate live validation; these earlier demonstrations must not
be presented as executions of the new maintenance workflow.
