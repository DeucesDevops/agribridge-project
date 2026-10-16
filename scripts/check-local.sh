#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .local/reports
# Never run the integration suite against the demo database.
if [ "$(docker compose exec -T postgres psql -U agribridge -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='agribridge_test'")" != 1 ]; then
  docker compose exec -T postgres createdb -U agribridge agribridge_test
fi
docker build --target test -t agribridge-api:check api
docker build --target test -t agribridge-web:check web
# Named containers allow copying reports after the checks finish.
api_check="agribridge-api-check-$$"
web_check="agribridge-web-check-$$"
trap 'docker rm -f "$api_check" "$web_check" >/dev/null 2>&1 || true' EXIT HUP INT TERM
docker run --name "$api_check" --network agribridge_default --env-file .env \
  -e PGHOST=postgres -e PGDATABASE=agribridge_test -e PGUSER=agribridge \
  -e REDIS_ENABLED=false -e NODE_ENV=test agribridge-api:check \
  sh -c 'npm run lint && npm run test:coverage && cp reports/junit.xml reports/unit-junit.xml && npm run test:integration && cp reports/junit.xml reports/integration-junit.xml'
docker cp "$api_check:/app/reports/." .local/reports/
docker cp "$api_check:/app/coverage" .local/reports/api-coverage
docker run --name "$web_check" agribridge-web:check sh -c 'npm run lint && npm run test:coverage && npm run build'
docker cp "$web_check:/app/coverage" .local/reports/web-coverage
