#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
case "${1:-up}" in
  up|build)
    # Never overwrite credentials belonging to an existing database volume.
    if [ ! -f .env ]; then
      git check-ignore -q .env || { echo '.env must be ignored before credentials are generated.' >&2; exit 1; }
      umask 077
      python3 - <<'PY'
import os
import secrets
with open('.env', 'x') as target:
    for key in ('PGPASSWORD', 'REDIS_PASSWORD', 'JWT_SECRET', 'SEED_PASSWORD'):
        target.write(f'{key}={secrets.token_hex(32)}\n')
    target.write('WEB_PORT=8081\n')
os.chmod('.env', 0o600)
print('Generated local credentials in .env (owner access only).')
PY
    fi
    export APP_VERSION="$(python3 -c "import json; print(json.load(open('api/package.json'))['version'])")"
    export GIT_SHA="$(git rev-parse HEAD)"
    export BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    export IMAGE_TAG="local-$(git rev-parse --short HEAD)"
    if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
      export IMAGE_TAG="${IMAGE_TAG}-dirty"
    fi
    # Persist only public build identity so plain Compose commands use the same tag.
    python3 - <<'PY'
from pathlib import Path
import os
p = Path('.env')
keys = ('APP_VERSION', 'GIT_SHA', 'BUILD_DATE', 'IMAGE_TAG')
lines = [line for line in p.read_text().splitlines() if not line.startswith(tuple(k + '=' for k in keys))]
p.write_text('\n'.join(lines) + '\n' + ''.join(f'{key}={os.environ[key]}\n' for key in keys))
PY
    if [ "${1:-up}" = build ]; then
      docker compose build
    else
      docker compose up -d --build --wait --wait-timeout 180
    fi
    ;;
  start) docker compose up -d --wait --wait-timeout 180 ;;
  stop) docker compose stop ;;
  down) docker compose down ;;
  status) docker compose ps ;;
  *) echo 'Usage: scripts/local.sh [up|build|start|stop|down|status]' >&2; exit 2 ;;
esac
