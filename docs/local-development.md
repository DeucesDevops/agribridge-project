# Local Docker environment (stages 1 and 2)

AgriBridge runs at **http://127.0.0.1:8081** using Docker Desktop. Prerequisites:
Docker Desktop with Compose, Git, Python 3 and a POSIX shell. Run commands from the
repository root. Existing Docker projects can keep running.

## Everyday commands

```sh
./scripts/local.sh up       # first run: generate local secrets, build, start and wait
./scripts/local.sh status
./scripts/local.sh stop     # stop this stack and keep its containers/data
./scripts/local.sh start    # start the existing images without rebuilding
./scripts/local.sh down     # remove this stack's containers/network; keep database volume
```

Use `up` after changing source or Dockerfiles. It records the package version, current
Git commit and UTC build date automatically. Uncommitted work produces a `-dirty` image
tag; `/version` identifies its base commit and marks the artifact as dirty via that tag.
This local build is not an immutable published release. No image or Git change is pushed.

If port 8081 is occupied, change `WEB_PORT` in the root `.env`, then run `up` again.
Only the web service publishes a host port, bound to `127.0.0.1`. PostgreSQL, Redis and
the API are accessible only inside this Compose project's network.

## Demo login and local credentials

Open the root **`.env`** file privately in your editor. **`SEED_PASSWORD`** is the password
shared by the seeded demo accounts. Select a persona on the login page, then paste that
password. The shortcuts fill only the email address.

| Role | Email |
| --- | --- |
| Farmer | `amina.yusuf@example.ng` |
| Buyer | `procurement@sahelmills.example` |
| Field agent | `agent@agribridge.example` |

The first `up` generates four independent random 256-bit values: `PGPASSWORD`,
`REDIS_PASSWORD`, `JWT_SECRET` and `SEED_PASSWORD`. The file is ignored by Git and has
owner-only permissions. It also contains the public port and build identity. Secrets enter
containers at runtime; the build contexts allow only explicit application inputs.
Do not share `.env`, expanded `docker compose config` output or container environment
inspection output. Local files are allowed by README §4.3; deployed environments must
use a secrets manager in a later stage.

Keep `.env` with the database volume. The initialization script does not overwrite it.
Changing a PostgreSQL initialization password in `.env` does not change an existing
PostgreSQL user's password. Likewise, changing `SEED_PASSWORD` does not update existing
account hashes: seeding skips an already populated database. Credential rotation must
update the corresponding database state and restart the API; it never requires an image
rebuild. Do not delete the database volume to perform routine updates.

## Runtime and image decisions

- API: Node 24 on Debian Bookworm slim. `npm ci --omit=dev` installs the locked production
  dependencies in a separate stage. The final image contains `src/`, the package manifest
  and production dependencies, and runs `node src/server.js` as UID/GID 1000. Tests and
  test dependencies remain in a separate `test` target. The API needs no writable source
  directory; it logs to stdout and stores data in PostgreSQL.
- Web: the same Node base builds Vite assets. The final image contains only the generated
  static assets and Nginx configuration on Nginx's unprivileged Alpine image (UID/GID
  101). Nginx uses its base image's writable `/tmp` paths. There is no API URL or secret
  baked into the browser bundle.
- Bases are pinned to registry-verified multi-platform digests, including ARM64 and AMD64.
  Builds use the host's native platform. Only ARM64 was executed here. To take base-image
  updates, verify the upstream tag's new manifest, update its digest, rebuild and rerun
  checks. Dependency updates go through the lockfiles and the same checks.
- Nginx keeps `/api` intact when proxying to `api:3000` and also proxies root `/healthz`,
  `/readyz`, `/metrics` and `/version`. Docker DNS is resolved dynamically so replacing
  the API container does not require restarting Nginx. All browser requests share one
  origin, including the httpOnly session cookie. `COOKIE_SECURE=false` is an explicit
  runtime setting for this loopback HTTP environment.
- PostgreSQL 17 stores its database in the named `agribridge_postgres-data` volume. Its
  official entrypoint initializes ownership then runs the server as the postgres user.
  Redis 8 runs as the redis user with password authentication; it is a disposable cache.
  Redis reads its password from stdin configuration, keeping it out of process arguments.
- API startup waits for healthy backing services, retries the database, then runs the
  existing advisory-lock-protected migrations and idempotent seed. Redis is optional at
  runtime (`REDIS_REQUIRED=false`): its loss costs caching, while database loss prevents
  readiness. Compose healthchecks report readiness; Docker does not restart a container
  merely because a healthcheck becomes unhealthy.
- The API receives SIGTERM directly and has a 10-second drain limit; Compose allows
  20 seconds before forcing termination. PostgreSQL receives 30 seconds to stop.

## Repeatable checks

```sh
./scripts/check-local.sh
python3 scripts/verify-local.py
```

The check script runs both linters, API coverage/unit tests, the separate real-PostgreSQL
integration suite, web coverage/unit tests and the production web build. Integration tests
use **`agribridge_test`**, never the demo database. API JUnit reports and coverage output
are copied into ignored `.local/reports/`. Lint errors fail; existing warning-level style
rules remain warnings for this local stage. No lint warnings were emitted in this run.

The smoke check uses the Nginx origin, validates cookie login/logout and operational
routes, creates a 3-tonne farmer lot, places a 1-tonne buyer order, and matches it as the
farmer. It intentionally leaves this demonstration data in the app. To demonstrate
persistence, run the smoke check once, then:

```sh
docker compose up -d --force-recreate --wait --wait-timeout 180 postgres api
python3 scripts/verify-local.py --persisted
```

This confirms that the same lot, remaining capacity, order and two audit events survived
container replacement. The saved IDs are in ignored `.local/verification.json`.

For dependency audits (nonzero means findings), use the two check images:

```sh
docker run --rm agribridge-api:check npm audit
docker run --rm agribridge-web:check npm audit
```

## Backup and restore rehearsal

A local backup and restore was tested in a separate database. This does not replace
managed backup retention and recovery planning for later environments. The dump contains
application data and password hashes; keep it private and outside Git.

```sh
umask 077
mkdir -p .local/backups
docker compose exec -T postgres pg_dump -U agribridge -d agribridge -Fc > .local/backups/agribridge.dump
# Use a fresh rehearsal database name if this one already exists.
docker compose exec -T postgres createdb -U agribridge agribridge_restore_check
docker compose exec -T postgres pg_restore -U agribridge -d agribridge_restore_check --no-owner < .local/backups/agribridge.dump
# Compare both databases' row counts or query known smoke-check IDs.
docker compose exec -T postgres psql -U agribridge -d agribridge_restore_check -c 'SELECT count(*) FROM orders;'
```

`down` retains the database. **`docker compose down -v` deletes its volume and data**;
that is a deliberate reset, not a normal stop command.

## Verified baseline — 16 October 2026

| Check | Result |
| --- | --- |
| Locked installs, API/web images, non-root application runtimes | Passed on Docker Desktop ARM64 |
| API lint / web lint | Passed, no warnings |
| API unit / PostgreSQL integration / web unit | 40 / 28 / 15 passed (README counts are older) |
| API domain coverage gate | 100% statements, lines and functions; 95.23% branches; all exceed 70% |
| Web coverage | Existing helper tests pass; overall line coverage 7.66%; no configured gate |
| Vite production bundle | Largest chunk 140.87 kB; below the configured 250 kB warning limit |
| Login page in browser; login/logout through Nginx | Passed; httpOnly cookie, no Secure flag on local HTTP |
| Farmer lot → buyer order → farmer match | Passed through the single origin |
| Redis cache and metrics | Readiness/cache ping healthy; repeated browse reports cache hit |
| Redis interruption | Readiness HTTP 200 with degraded=true; browsing still works |
| PostgreSQL interruption | Liveness HTTP 200; readiness HTTP 503 |
| API graceful termination | SIGTERM, HTTP drained, dependencies closed, exit code 0 |
| PostgreSQL/API recreation | Lot, remaining tonnage, order and event history retained |
| Backup restored into a separate database | All four table counts match: 9 users, 9 lots, 7 orders, 8 events |

Dependency audits found pre-existing lockfile issues: **19 API findings** across all
installed dependencies (4 critical, 6 high, 5 moderate, 4 low) and **11 web findings**
(3 critical, 4 high, 2 moderate, 2 low). Full audit JSON is saved in `.local/reports/`.
These counts include test/build tooling. The API production-only audit has **7 findings**
(1 critical, 2 high, 2 moderate, 2 low), saved separately as `api-runtime-audit.json`.
Dependency remediation requires its own reviewed update and
verification. Functional checks passing do not clear these audit findings.

Stages 1 and 2 cover this local baseline, images and minimal Compose environment.
Terraform, kOps/Kubernetes, Helm, GitHub Actions, deployed secrets, TLS and centralized
monitoring remain later deliverables from the assignment. No release or cloud deployment
has been made.
