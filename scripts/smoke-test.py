"""Verify public HTTPS readiness and exact build identity after an Argo CD sync."""
import argparse
import json
import subprocess
from pathlib import Path
import time
from urllib.request import urlopen
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("environment", choices=["staging", "production"])
parser.add_argument("image_tag")
parser.add_argument("--timeout", type=int, default=900)
parser.add_argument("--runtime", action="store_true", help="Also verify runtime secrets, migrations and staging login using kubectl")
args = parser.parse_args()
values = yaml.safe_load(Path("argocd/" + args.environment + "-values.yaml").read_text())
hostname = values["hostname"]
if hostname != args.environment + ".agribridge.deuces.dev":
    raise SystemExit("Unexpected release hostname")
origin = "https://" + hostname
deadline = time.monotonic() + args.timeout
last_error = "not checked"
while time.monotonic() < deadline:
    try:
        with urlopen(origin + "/readyz", timeout=10) as response:
            if response.status != 200:
                raise ValueError("API is not ready")
        with urlopen(origin + "/version", timeout=10) as response:
            version = json.loads(response.read(65536))
        if version.get("imageTag") != args.image_tag:
            raise ValueError("Waiting for requested image tag")
        if version.get("gitSha") != args.image_tag.split("-")[0]:
            raise ValueError("Running source commit does not match the artifact")
        with urlopen(origin + "/", timeout=10) as response:
            if response.status != 200:
                raise ValueError("Frontend is not ready")
        print(args.environment + " HTTPS, readiness and build identity passed.")
        break
    except Exception as error:
        last_error = type(error).__name__ + ": " + str(error)
        time.sleep(10)
else:
    raise SystemExit("Release verification timed out: " + last_error)

if args.runtime:
    source = r'''
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
'''
    subprocess.run(['kubectl', '-n', 'agribridge-' + args.environment, 'exec', '-i',
                    'deployment/agribridge-api', '--', 'node', '--input-type=module', '-',
                    args.image_tag, args.environment], input=source, text=True, check=True)
