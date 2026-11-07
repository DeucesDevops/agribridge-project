#!/usr/bin/env bash
# Read-only live acceptance. Secret values remain inside the running API pod.
set -euo pipefail
cd "$(dirname "$0")/.."
environment=$1
case "$environment" in staging|production) ;; *) echo 'Choose staging or production.' >&2; exit 2 ;; esac
export KUBECONFIG="$PWD/.runtime/kubeconfig"
test "$(kubectl config current-context)" = k8s.agribridge.deuces.dev || exit 1
image_tag=$(python3 - "$environment" <<'PY'
import sys, yaml
from pathlib import Path
values = yaml.safe_load(Path('argocd/' + sys.argv[1] + '-values.yaml').read_text())
if not values['releaseEnabled']:
    raise SystemExit('No release has been enabled yet. Fetch the reviewed CI commit first.')
print(values['api']['tag'])
PY
)
namespace="agribridge-$environment"
kubectl -n "$namespace" get externalsecrets,secretstores,pods,pvc
kubectl -n "$namespace" wait --for=condition=Ready externalsecret/agribridge --timeout=300s
kubectl -n "$namespace" rollout status statefulset/agribridge-postgres --timeout=300s
kubectl -n "$namespace" rollout status deployment/agribridge-api --timeout=300s
kubectl -n "$namespace" rollout status deployment/agribridge-web --timeout=300s
kubectl -n "$namespace" exec -i deployment/agribridge-api -- node --input-type=module - "$image_tag" "$environment" <<'JS'
import assert from 'node:assert/strict';
import { readdir } from 'node:fs/promises';
const [tag, environment] = process.argv.slice(2);
for (const key of ['PGPASSWORD', 'JWT_SECRET', 'SEED_PASSWORD']) {
  assert.ok(process.env[key]?.length >= 32, 'Missing runtime secret: ' + key);
}
const origin = 'https://' + environment + '.agribridge.deuces.dev';
assert.equal((await fetch(origin + '/readyz')).status, 200);
const version = await (await fetch(origin + '/version')).json();
assert.equal(version.imageTag, tag);
assert.equal(version.gitSha, tag.split('-')[0]);
assert.equal((await fetch(origin)).status, 200);
const { pool } = await import('./src/db.js');
try {
  const expected = (await readdir('./src/migrations')).filter(name => name.endsWith('.sql')).sort();
  const { rows } = await pool.query('SELECT filename FROM schema_migrations ORDER BY filename');
  assert.deepEqual(rows.map(row => row.filename), expected);
} finally {
  await pool.end();
}
if (environment === 'staging') {
  let login;
  for (let attempt = 0; attempt < 60; attempt++) {
    login = await fetch(origin + '/api/auth/login', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email: 'amina.yusuf@example.ng', password: process.env.SEED_PASSWORD}),
    });
    if (login.ok) break;
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
  assert.equal(login.status, 200, 'Staging seed/login did not complete');
  const cookie = login.headers.get('set-cookie');
  assert.ok(cookie?.includes('HttpOnly') && cookie.includes('Secure'));
  assert.equal((await fetch(origin + '/api/auth/me', {
    headers: {Cookie: cookie.split(';')[0]},
  })).status, 200);
}
console.log(environment + ': runtime secrets, migrations, HTTPS and exact build identity passed.');
JS
