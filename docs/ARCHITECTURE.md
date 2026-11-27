# Architecture

AgriBridge is four processes. The browser talks to the web app. The web app calls the API. The API reads and writes PostgreSQL and optionally caches in Redis.

```text
browser
  |
  |  http://localhost:8080  (Compose) or http://localhost:5173 (Vite)
  v
web (NGINX or Vite)
  |
  |  /api, /readyz, /version
  v
API (Express :3000)
  |                 \
  |                  \  optional
  v                   v
PostgreSQL           Redis
```

Locally, Docker Compose runs all four. Without Compose, run PostgreSQL, Redis, `npm run dev` in `api/` and `npm run dev` in `frontend/`. Vite then serves the React app and proxies `/api`.

## Web

The UI is a single React page with four views: dashboard, the farmer's lots, the buyer's open lots, and orders. Which tabs appear depends on the signed-in role. Farmer and agent see produce. Buyer and agent see open lots. There is no client-side router; view state stays in the root component so the bundle stays small.

NGINX in `frontend/nginx.conf.template` routes the container port `8080` as follows.

| Path | Who answers |
|---|---|
| `/` and `/assets/` | The built React app |
| `/api/` | Proxied to the API. The prefix is unchanged |
| `/healthz` | NGINX returns `ok` |
| `/readyz` | Proxied to the API `/readyz` |
| `/version` | Proxied to the API `/version` |

`/metrics` is not proxied by NGINX. Scrape it on the API port.

## API

Application routes live under `/api`. Operational routes live at the root so probes do not depend on the `/api` prefix.

| Method and path | Purpose |
|---|---|
| `POST /api/auth/login` | Session cookie |
| `POST /api/auth/logout` | Clear the session |
| `GET /api/auth/me` | Current user |
| `/api/lots` | Publish and browse produce |
| `/api/orders` | Place orders and change status |
| `POST /api/orders/credit-check` | Farmer input-credit eligibility |
| `GET /api/stats/summary` | Dashboard totals |
| `GET /api/stats/by-crop` | Orders grouped by crop |
| `GET /api/stats/funnel` | Order counts by status |
| `GET /healthz` | Process is alive. Does not touch PostgreSQL or Redis |
| `GET /readyz` | PostgreSQL is reachable. Redis down is degradation unless `REDIS_REQUIRED=true` |
| `GET /version` | Build identity from `APP_VERSION`, `GIT_SHA`, `BUILD_DATE` and `IMAGE_TAG` |
| `GET /metrics` | Process and business metrics in Prometheus text format |

Authentication is a signed JWT in an httpOnly cookie. The API does not create users except through the demo seed.

Pricing is a pure function in `api/src/domain/pricing.js`. Grade A keeps the asking price, grade B multiplies by 0.93 and grade C by 0.85. The platform fee is 2.5% of the graded total and is taken from the farmer payout. Order tonnage must be between 0.5 and 5000.

Credit eligibility is a pure function in `api/src/domain/credit.js`. A farmer can request an advance of up to 40% of settled order value from the trailing 365 days, capped at 2,000,000 naira, and only after at least one qualifying settled order.

On shutdown the API stops accepting connections, waits up to `SHUTDOWN_GRACE_MS` for in-flight requests, then closes PostgreSQL and Redis.

## Data

`api/src/migrations/001_init.sql` creates the schema. `api/src/migrate.js` applies it under a Postgres advisory lock so several API processes can start together.

| Table | Contents |
|---|---|
| `users` | Farmer, buyer and agent accounts |
| `lots` | Produce offered for sale: crop, tonnage, grade, state, price, status |
| `orders` | A buyer's purchase of part of a lot, including fee and payout |
| `order_events` | Append-only status changes, with the actor and request id |

Lot status is `OPEN`, `RESERVED`, `SOLD` or `WITHDRAWN`. Order status is `PENDING`, `MATCHED`, `IN_TRANSIT`, `DELIVERED`, `SETTLED` or `CANCELLED`.

`api/src/seed.js` inserts demo farmers, buyers, an agent, lots and orders when `SEED_DEMO_DATA` is true and `users` is empty. It requires `SEED_PASSWORD`.

Redis caches dashboard aggregates. A cache miss or a Redis outage falls back to PostgreSQL. Query labels and metric labels stay low-cardinality: they use a logical operation name or the route template, never an order id or user id.

Logs are one JSON object per line on stdout, with a `request_id` that matches the `X-Request-Id` response header and the `request_id` stored on `order_events`.
