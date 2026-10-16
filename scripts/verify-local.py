#!/usr/bin/env python3
"""Smoke-test the running Nginx origin; never print or save session credentials."""
import http.cookiejar
import json
from pathlib import Path
import sys
import urllib.error
import urllib.request

root = Path(__file__).resolve().parent.parent
settings = dict(line.split('=', 1) for line in (root / '.env').read_text().splitlines() if '=' in line)
origin = f"http://127.0.0.1:{settings.get('WEB_PORT', '8081')}"


def session(email):
    jar = http.cookiejar.CookieJar()
    client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    call(client, '/api/auth/login', {'email': email, 'password': settings['SEED_PASSWORD']})
    cookie = next(c for c in jar if c.name == 'agribridge_session')
    assert cookie.has_nonstandard_attr('HttpOnly') and not cookie.secure
    assert call(client, '/api/auth/me')['user']['email'] == email
    return client


def call(client, path, data=None, method=None):
    request = urllib.request.Request(origin + path, method=method,
        data=json.dumps(data).encode() if data is not None else None,
        headers={'Content-Type': 'application/json'} if data is not None else {})
    with client.open(request, timeout=15) as response:
        return json.load(response)


public = urllib.request.build_opener()
with public.open(origin) as response:
    assert b'<div id="root">' in response.read()
assert call(public, '/healthz')['status'] == 'ok'
ready = call(public, '/readyz')
assert ready['status'] == 'ready' and not ready['degraded']
assert ready['checks']['database']['ok'] and ready['checks']['cache']['ok']
version = call(public, '/version')
assert version['gitSha'] == settings['GIT_SHA'] and version['builtAt'] != 'unknown'
try:
    call(public, '/api/auth/me')
    raise AssertionError('Unauthenticated route accepted')
except urllib.error.HTTPError as error:
    assert error.code == 401
farmer = session('amina.yusuf@example.ng')
buyer = session('procurement@sahelmills.example')
record = root / '.local' / 'verification.json'
if '--persisted' in sys.argv:
    saved = json.loads(record.read_text())
    lot = call(public, '/api/lots/' + saved['lot'])['lot']
    order = call(buyer, '/api/orders/' + saved['order'])
    assert lot['id'] == saved['lot'] and float(lot['tonnage']) == 2
    assert order['order']['status'] == 'MATCHED' and len(order['events']) == 2
    print('PASS: lot, reserved capacity, order and audit events survived container recreation.')
else:
    lot = call(farmer, '/api/lots', {'crop': 'maize', 'tonnage': 3,
        'moistureGrade': 'A', 'state': 'Kano', 'pricePerTonneNaira': 620000})['lot']
    order = call(buyer, '/api/orders', {'lotId': lot['id'], 'tonnage': 1})['order']
    matched = call(farmer, '/api/orders/' + order['id'] + '/status', {'status': 'MATCHED'}, 'PATCH')
    assert matched['order']['status'] == 'MATCHED'
    record.parent.mkdir(exist_ok=True)
    record.write_text(json.dumps({'lot': lot['id'], 'order': order['id']}) + '\n')
    print('PASS: farmer created a lot; buyer ordered; farmer matched the order through Nginx.')
# Exercise repeated reads and verify actual cache hits are exposed.
call(public, '/api/lots')
assert call(public, '/api/lots').get('cached') is True
with public.open(origin + '/metrics') as response:
    metrics = response.read().decode()
    assert 'agribridge_build_info' in metrics and 'result="hit"' in metrics
call(farmer, '/api/auth/logout', {})
try:
    call(farmer, '/api/auth/me')
    raise AssertionError('Logout left a valid session')
except urllib.error.HTTPError as error:
    assert error.code == 401
print('PASS: static page, health, readiness, build identity, cookie login/logout and Redis cache.')
print('Running:', origin)
