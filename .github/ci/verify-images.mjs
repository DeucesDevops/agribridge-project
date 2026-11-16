// Acceptance checks against the exact images CI will scan and publish.
import assert from 'node:assert/strict';

const origin = process.env.CI_APP_URL || 'http://localhost:8080';
const get = (path, options = {}) => fetch(origin + path, {
  ...options, signal: AbortSignal.timeout(10_000),
});
assert.ok(process.env.IMAGE_TAG && process.env.GIT_SHA, 'Build identity is required');
assert.equal((await get('/')).status, 200, 'Frontend must serve the application');
assert.equal((await get('/readyz')).status, 200, 'API must be ready through NGINX');
const version = await (await get('/version')).json();
assert.equal(version.imageTag, process.env.IMAGE_TAG, 'Wrong image tag');
assert.equal(version.gitSha, process.env.GIT_SHA, 'Wrong source commit');
const login = await get('/api/auth/login', {
  method: 'POST', headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: 'amina.yusuf@example.ng', password: 'local-demo-password-only'}),
});
assert.equal(login.status, 200, 'Demo authentication must work');
const cookie = login.headers.get('set-cookie');
assert.ok(cookie?.includes('HttpOnly'), 'Login must set an HttpOnly cookie');
assert.equal((await get('/api/auth/me', {
  headers: {Cookie: cookie.split(';')[0]},
})).status, 200, 'Same-origin authenticated requests must work');
console.log('Exact images passed readiness, build identity and same-origin authentication.');
