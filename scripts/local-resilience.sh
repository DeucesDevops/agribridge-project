#!/usr/bin/env bash
set -euo pipefail
# Run after docker compose up --build -d --wait. Uses only the local stack.
trap 'docker compose start redis >/dev/null' EXIT
docker compose stop redis
# Restart verifies that the API boots while Redis is already absent.
docker compose restart api
docker compose exec -T api node --input-type=module <<'JS'
for (let attempt = 0; attempt < 30; attempt++) {
  try {
    const response = await fetch('http://localhost:3000/readyz');
    const data = await response.json();
    if (response.ok && data.degraded) {
      const login = await fetch('http://localhost:3000/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'amina.yusuf@example.ng', password: process.env.SEED_PASSWORD }),
      });
      const cookie = login.headers.get('set-cookie');
      if (!login.ok || !cookie) throw new Error('login failed while Redis was absent');
      const lots = await fetch('http://localhost:3000/api/lots', {
        headers: { Cookie: cookie.split(';')[0] },
      });
      if (!lots.ok) throw new Error('application read failed while Redis was absent');
      console.log('API remained ready and served authenticated requests with Redis absent.');
      process.exit(0);
    }
  } catch { /* startup */ }
  await new Promise(resolve => setTimeout(resolve, 1000));
}
process.exit(1);
JS
before=$(docker compose exec -T postgres psql -At -U agribridge -c 'SELECT count(*) FROM users')
docker compose restart postgres
docker compose exec -T api node --input-type=module <<'JS'
for (let attempt = 0; attempt < 30; attempt++) {
  try {
    const response = await fetch('http://localhost:3000/readyz');
    if (response.ok) process.exit(0);
  } catch { /* recovery */ }
  await new Promise(resolve => setTimeout(resolve, 1000));
}
process.exit(1);
JS
after=$(docker compose exec -T postgres psql -At -U agribridge -c 'SELECT count(*) FROM users')
test "$before" = "$after"
echo "PostgreSQL restart preserved $after users."
