#!/usr/bin/env bash
# Build and verify a disposable, isolated local stack. No AWS/GitHub operations.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077

if ! docker info --format '{{.ServerVersion}}'; then
  echo 'Docker engine is unavailable to this shell. Docker Desktop must be running and this shell must have permission to access its socket.' >&2
  exit 1
fi

# Never reuse a development database or inherit its connection credentials.
export COMPOSE_PROJECT_NAME="agribridge-verify-$(date +%s)-$$"
export COMPOSE_FILE="$PWD/docker-compose.yml"
export PG_LOCAL_PORT="${VERIFY_PG_PORT:-15433}"
export WEB_LOCAL_PORT="${VERIFY_WEB_PORT:-18080}"
export PGPASSWORD JWT_SECRET SEED_PASSWORD
PGPASSWORD=$(node -e 'process.stdout.write(require("node:crypto").randomBytes(24).toString("hex"))')
JWT_SECRET=$(node -e 'process.stdout.write(require("node:crypto").randomBytes(32).toString("hex"))')
SEED_PASSWORD=$(node -e 'process.stdout.write(require("node:crypto").randomBytes(24).toString("hex"))')
export API_IMAGE=agribridge-api WEB_IMAGE=agribridge-web
export APP_VERSION GIT_SHA BUILD_DATE IMAGE_TAG
APP_VERSION=$(node -p 'require("./api/package.json").version')
GIT_SHA=$(git rev-parse HEAD)
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
IMAGE_TAG="local-verification-$(date +%s)-$$"

cleanup() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ]; then docker compose ps --all || true; fi
  # This project and its volumes were created solely for this test run.
  if ! docker compose down --volumes --remove-orphans; then
    echo "Cleanup failed for $COMPOSE_PROJECT_NAME; inspect it in Docker Desktop." >&2
    status=1
  fi
  exit "$status"
}
trap cleanup EXIT

docker compose build
docker compose up -d --wait --wait-timeout 240

# Check the frontend, same-origin login routing and session cookie without
# printing a password or cookie. These are local throwaway credentials only.
node --input-type=module <<'JS'
import assert from 'node:assert/strict';
const origin = `http://127.0.0.1:${process.env.WEB_LOCAL_PORT}`;
assert.equal((await fetch(origin)).status, 200);
assert.equal((await fetch(origin + '/readyz')).status, 200);
const publicVersion = await (await fetch(origin + '/version')).json();
assert.equal(publicVersion.imageTag, process.env.IMAGE_TAG);
assert.equal(publicVersion.gitSha, process.env.GIT_SHA);
const login = await fetch(`${origin}/api/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'amina.yusuf@example.ng', password: process.env.SEED_PASSWORD }),
});
assert.equal(login.status, 200, 'same-origin login failed');
const cookie = login.headers.get('set-cookie');
assert.ok(cookie?.includes('HttpOnly'), 'session cookie must be HttpOnly');
const me = await fetch(`${origin}/api/auth/me`, { headers: { Cookie: cookie.split(';')[0] } });
assert.equal(me.status, 200, 'session cookie was not accepted');
console.log('Frontend, same-origin login and authenticated session passed.');
JS

docker compose exec -T api node --input-type=module <<'JS'
import assert from 'node:assert/strict';
const response = await fetch('http://localhost:3000/version');
assert.equal(response.status, 200);
const version = await response.json();
assert.equal(version.imageTag, process.env.IMAGE_TAG);
assert.equal(version.gitSha, process.env.GIT_SHA);
console.log('Running API identity matches the local verification build.');
JS

# Integration suites clean their rows in their own database, not the seeded app.
docker compose exec -T postgres createdb -U agribridge agribridge_test
PGHOST=127.0.0.1 PGPORT="$PG_LOCAL_PORT" PGUSER=agribridge \
  PGDATABASE=agribridge_test PGSSL=false REDIS_ENABLED=false \
  npm run test:integration --prefix api

bash scripts/local-resilience.sh

# Prove the volume survives replacement of the database container, using an
# exact marker that demo seeding cannot regenerate.
marker=$(node -e 'process.stdout.write(require("node:crypto").randomBytes(16).toString("hex"))')
docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U agribridge <<SQL
CREATE TABLE stage2_persistence_probe (marker text PRIMARY KEY);
INSERT INTO stage2_persistence_probe VALUES ('$marker');
SQL
docker compose up -d --no-deps --force-recreate --wait --wait-timeout 120 postgres
persisted=$(docker compose exec -T postgres psql -At -U agribridge -c 'SELECT marker FROM stage2_persistence_probe')
test "$persisted" = "$marker"
echo 'Exact persistence marker survived PostgreSQL container replacement.'

# The resilience helper restores Redis. Wait for both dependencies to recover.
docker compose exec -T api node --input-type=module <<'JS'
for (let attempt = 0; attempt < 60; attempt++) {
  try {
    const response = await fetch('http://localhost:3000/readyz');
    const data = await response.json();
    if (response.ok && !data.degraded && data.checks.database.ok && data.checks.cache.ok) {
      console.log('API is ready with PostgreSQL and Redis healthy again.');
      process.exit(0);
    }
  } catch { /* dependencies may still be recovering */ }
  await new Promise(resolve => setTimeout(resolve, 1000));
}
throw new Error('dependencies did not recover');
JS

echo 'Local verification passed: containers, integration, persistence and cache degradation.'
