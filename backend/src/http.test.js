import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createApp } from './http.js';

// None of these requests carries a real token, so nothing reaches Supabase.
const configured = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
};
const listNotifications = '/sprout.v1.NotificationService/ListNotifications';

let server;
let base;
const saved = {};

before(async () => {
  for (const key of [...Object.keys(configured), 'CLIENT_ORIGIN']) saved[key] = process.env[key];
  delete process.env.CLIENT_ORIGIN;
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.close();
  for (const [key, value] of Object.entries(saved)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
});

function setEnv(values) {
  for (const key of Object.keys(configured)) {
    if (values[key] === undefined) delete process.env[key];
    else process.env[key] = values[key];
  }
}

function connectCall(headers = {}) {
  return fetch(`${base}${listNotifications}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: '{}',
  });
}

async function quietly(run) {
  const original = console.error;
  console.error = () => {};
  try {
    return await run();
  } finally {
    console.error = original;
  }
}

test('health still answers', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true });
});

test('REST notifications without a token is still 401 with the same message', async () => {
  setEnv(configured);
  const res = await fetch(`${base}/api/me/notifications`);
  assert.equal(res.status, 401);
  assert.deepEqual(await res.json(), { message: 'Sign in to continue.' });

  const malformed = await fetch(`${base}/api/me/notifications`, {
    headers: { Authorization: 'Token abc' },
  });
  assert.equal(malformed.status, 401);
  assert.deepEqual(await malformed.json(), { message: 'Sign in to continue.' });
});

test('REST is still 503 when Supabase is not configured', async () => {
  setEnv({});
  const res = await quietly(() =>
    fetch(`${base}/api/plants`, { headers: { Authorization: 'Bearer anything' } }),
  );
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { message: 'API is not configured.' });
});

test('REST routes still get parsed JSON bodies', async () => {
  setEnv(configured);
  const res = await fetch(`${base}/public/signup-email`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'not-an-email' }),
  });
  assert.equal(res.status, 400);
  assert.deepEqual(await res.json(), { message: 'Enter a valid email.' });
});

test('Connect without a token is unauthenticated, not a REST error', async () => {
  setEnv(configured);
  const res = await connectCall();
  assert.equal(res.status, 401);
  assert.deepEqual(await res.json(), {
    code: 'unauthenticated',
    message: 'Sign in to continue.',
  });
});

test('Connect is unavailable when Supabase is not configured', async () => {
  setEnv({});
  const res = await quietly(() => connectCall({ Authorization: 'Bearer anything' }));
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), {
    code: 'unavailable',
    message: 'API is not configured.',
  });
});

test('browsers may call Connect and read its error headers', async () => {
  const preflight = await fetch(`${base}${listNotifications}`, {
    method: 'OPTIONS',
    headers: {
      Origin: 'http://localhost:8125',
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers':
        'authorization,content-type,connect-protocol-version,x-utc-offset-minutes',
    },
  });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), 'http://localhost:8125');
  assert.match(preflight.headers.get('access-control-allow-headers'), /authorization/);
  assert.match(preflight.headers.get('access-control-allow-headers'), /x-utc-offset-minutes/);
  assert.match(preflight.headers.get('access-control-allow-methods'), /POST/);

  setEnv(configured);
  const res = await connectCall({ Origin: 'http://localhost:8125' });
  assert.match(res.headers.get('access-control-expose-headers'), /Grpc-Status/);
});
