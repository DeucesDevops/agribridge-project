# AgriBridge

AgriBridge is a grain marketplace. Farmers publish produce, buyers place orders, and both follow an order through fulfilment. The web app is React and Vite. The API is Express. PostgreSQL stores the marketplace data and Redis caches read-heavy responses.

## Features

- **Farmer workspace:** publish crop lots with quantity, moisture grade, price and location, and check input-credit eligibility against settled trade.
- **Buyer workspace:** browse open lots and place orders.
- **Order management:** move an order through pending, matched, in transit, delivered, settled and cancelled, with an append-only history of each change.
- **Dashboard:** open lots, tonnage, orders and monthly traded value, including a breakdown by crop.
- **Role-based access:** farmer, buyer and agent experiences. Sign-in uses an httpOnly cookie. The API does not register new users; accounts come from the demo seed.

Crops are maize, sorghum, soybean and paddy rice. Prices are in naira. Moisture grade A, B or C changes the price a buyer pays, and the platform fee is 2.5% of that graded value.

## Tech stack

| Layer | Choice |
|---|---|
| Frontend | React 18 and Vite, served by NGINX in the container image |
| API | Express on Node.js 22 |
| Database | PostgreSQL 16 |
| Cache | Redis 7 |
| Tests | Vitest |

The frontend never embeds an API hostname. In development, Vite proxies `/api` to the API. In the container image, NGINX does the same.

## Run locally with Docker Compose

Install Docker with Docker Compose v2.

```sh
git clone https://github.com/DeucesDevops/agribridge-project.git
cd agribridge-project
cp .env.example .env
docker compose up --build -d --wait
```

Open http://localhost:8080.

Compose builds the web app and the API, starts PostgreSQL and Redis, runs migrations and loads demonstration data. Replace the placeholder values in `.env` before you use the stack on a shared machine.

`make local` is the same Compose command. `make stop` runs `docker compose down` and keeps the database volume.

```sh
docker compose ps
docker compose logs -f api
docker compose down
```

The web port defaults to `8080`. Set `WEB_LOCAL_PORT` to change it. Local PostgreSQL is published on `5433` unless `PG_LOCAL_PORT` is set.

### Demo accounts

| Role | Email |
|---|---|
| Farmer | `amina.yusuf@example.ng` |
| Buyer | `procurement@sahelmills.example` |
| Agent | `agent@agribridge.example` |

The password for every demo account is the `SEED_PASSWORD` you set in `.env`. Compose sets `SEED_DEMO_DATA=true` and loads these accounts on startup, plus additional farmers, buyers, lots and orders. Seeding is skipped when the users table already has rows.

## Run locally without Docker Compose

Install Node.js 22, PostgreSQL 16 and Redis 7. Create a database the API can reach, then install dependencies:

```sh
npm ci --prefix api
npm ci --prefix frontend
```

Export the variables under [Environment variables](#environment-variables). For a local API process the usual database settings are host `localhost`, port `5432`, database `agribridge` and user `agribridge`. Set `PGPASSWORD`, `JWT_SECRET` and `SEED_PASSWORD` yourself.

```sh
npm run migrate --prefix api
SEED_DEMO_DATA=true npm run seed --prefix api
npm run dev --prefix api
npm run dev --prefix frontend
```

The API listens on port `3000`. Vite listens on port `5173` and proxies `/api` to `http://localhost:3000` unless `API_URL` is set. Open http://localhost:5173.

Redis is optional for local development. If it is not running, set `REDIS_ENABLED=false`. When Redis is enabled and unreachable, the API still reads PostgreSQL and `/readyz` reports the cache as degraded.

`NODE_ENV=production` refuses to start without `JWT_SECRET`. Development starts without that variable.

## Tests

From the repository root, with dependencies installed:

```sh
npm test --prefix api
npm run test:coverage --prefix api
npm run lint --prefix api
npm test --prefix frontend
npm run test:coverage --prefix frontend
npm run lint --prefix frontend
npm run build --prefix frontend
```

API unit tests cover pricing, credit eligibility, caching and order rules. Coverage thresholds apply to `api/src/domain`. Frontend tests cover display formatting.

Integration tests talk to a real PostgreSQL database. Create an empty database (the default name is `agribridge_test`) and export `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` and `PGDATABASE` before:

```sh
npm run test:integration --prefix api
```

## Environment variables

Names only. Set the values in a gitignored `.env` or in the process environment. Do not commit them.

### Compose file (`.env`)

| Name | Purpose |
|---|---|
| `PGPASSWORD` | PostgreSQL password for the Compose database and the API |
| `JWT_SECRET` | Signs the session cookie. Required because Compose runs the API with `NODE_ENV=production` |
| `SEED_PASSWORD` | Password stored for the demo accounts |
| `IMAGE_TAG` | Tag used when Compose names the built images |
| `APP_VERSION` | Build arg recorded on `/version` |
| `GIT_SHA` | Build arg recorded on `/version` |
| `BUILD_DATE` | Build arg recorded on `/version` |
| `API_IMAGE` | Image name for the API |
| `WEB_IMAGE` | Image name for the web app |
| `WEB_LOCAL_PORT` | Host port published for the web app |
| `PG_LOCAL_PORT` | Host port published for PostgreSQL |

### API process

| Name | Purpose |
|---|---|
| `NODE_ENV` | `development`, `test` or `production` |
| `PORT` | HTTP port. Default `3000` |
| `LOG_LEVEL` | `debug`, `info`, `warn` or `error` |
| `PGHOST` | PostgreSQL host |
| `PGPORT` | PostgreSQL port |
| `PGDATABASE` | Database name |
| `PGUSER` | Database user |
| `PGPASSWORD` | Database password |
| `PGSSL` | Enable TLS to PostgreSQL when true |
| `PG_POOL_MAX` | Pool maximum |
| `PG_POOL_MIN` | Pool minimum |
| `PG_CONNECT_TIMEOUT_MS` | Connection timeout |
| `PG_IDLE_TIMEOUT_MS` | Idle client timeout |
| `PG_STATEMENT_TIMEOUT_MS` | Statement timeout |
| `REDIS_ENABLED` | Turn the cache on or off |
| `REDIS_URL` | Redis connection URL |
| `REDIS_REQUIRED` | When true, `/readyz` fails if Redis is down |
| `CACHE_TTL_SECONDS` | Cache lifetime |
| `JWT_SECRET` | Session signing secret. Required in production |
| `TOKEN_TTL_SECONDS` | Session lifetime |
| `COOKIE_NAME` | Session cookie name |
| `COOKIE_SECURE` | Set the cookie `Secure` flag |
| `BCRYPT_ROUNDS` | Password hash cost |
| `SHUTDOWN_GRACE_MS` | How long in-flight requests may finish on shutdown |
| `RUN_MIGRATIONS` | Apply SQL migrations on startup |
| `SEED_DEMO_DATA` | Load demo data on startup when the database is empty |
| `SEED_PASSWORD` | Password used while seeding |
| `TRUST_PROXY` | Honor `X-Forwarded-For` from a reverse proxy |
| `APP_VERSION` | Reported by `/version` |
| `GIT_SHA` | Reported by `/version` |
| `BUILD_DATE` | Reported by `/version` |
| `IMAGE_TAG` | Reported by `/version` |

### Frontend and tests

| Name | Purpose |
|---|---|
| `API_URL` | Vite dev-server proxy target for `/api` |
| `API_UPSTREAM` | Host the NGINX image proxies to. Default `api:3000` |
| `JUNIT_FILE` | Where Vitest writes a JUnit report |

Copy `api/.env.example` when you run the API on the host. Copy the root `.env.example` when you use Compose.

## Repository layout

| Path | Purpose |
|---|---|
| `frontend/` | React application, Vite config, NGINX template and Dockerfile |
| `api/` | Express API, SQL migrations, demo seed and tests |
| `docker-compose.yml` | Local PostgreSQL, Redis, API and web app |
| `helm/agribridge` | Application chart. Argo CD syncs `values-production.yaml` |
| `terraform/` | State bootstrap, modules, and the production root |
| `kops/cluster.yaml` | kOps cluster spec for `k8s.agribridge.deuces.dev` |
| `platform/` | Argo CD, monitoring, and External Secrets values |
| `docs/ARCHITECTURE.md` | How a request moves through the application and the cluster |
| `docs/SETUP.md` | Local setup, then the cloud rebuild |
| `Makefile` | `local`, `stop`, `validate`, `plan`, `apply`, `teardown`, and `test` |

Cloud setup starts with `scripts/bootstrap-state.sh`. See [docs/SETUP.md](docs/SETUP.md). `make plan` and `make apply` talk to AWS. `make validate` does not.

## Further reading

Request paths, health checks and the data model are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
