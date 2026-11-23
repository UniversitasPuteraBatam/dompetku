const assert = require('node:assert/strict');
const { after, before, beforeEach, test } = require('node:test');
const { ipKeyGenerator } = require('express-rate-limit');

const {
  app,
  loginRateLimiter,
  pool,
  registerRateLimiter,
} = require('../index');
const localRateLimitKey = ipKeyGenerator('::ffff:127.0.0.1');

let server;
let baseUrl;

before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

beforeEach(async () => {
  await loginRateLimiter.resetKey(localRateLimitKey);
  await registerRateLimiter.resetKey(localRateLimitKey);
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

async function send(method, path, body) {
  return fetch(`${baseUrl}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

test('health reports a successful database check', async (t) => {
  const query = t.mock.method(pool, 'query', async (sql) => {
    assert.equal(sql, 'SELECT 1');
    return [[{ 1: 1 }], []];
  });

  const response = await send('GET', '/api/health');

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    success: true,
    message: 'DompetKu API berjalan',
    database: 'connected',
  });
  assert.equal(query.mock.callCount(), 1);
});

test('health hides database errors and redacts environment values from diagnostics', async (t) => {
  const originalPassword = process.env.DB_PASSWORD;
  const originalJwtSecret = process.env.JWT_SECRET;
  const passwordSentinel = 'mock-database-password-sentinel';
  const jwtSentinel = 'mock-jwt-secret-sentinel';
  process.env.DB_PASSWORD = passwordSentinel;
  process.env.JWT_SECRET = jwtSentinel;

  const log = t.mock.method(console, 'error');
  const query = t.mock.method(pool, 'query', async () => {
    const error = new Error(
      `access denied for ${passwordSentinel}; secret ${jwtSentinel}`,
    );
    error.code = 'ER_ACCESS_DENIED_ERROR';
    error.errno = 1045;
    error.sqlState = '28000';
    throw error;
  });

  try {
    const response = await send('GET', '/api/health');
    const responseBody = await response.json();

    assert.equal(response.status, 500);
    assert.deepEqual(responseBody, {
      success: false,
      message: 'Gagal terhubung ke database MySQL',
    });
    assert.equal(query.mock.callCount(), 1);
    assert.equal(log.mock.callCount(), 1);
    const diagnostic = JSON.stringify(log.mock.calls[0].arguments);
    assert.match(diagnostic, /ER_ACCESS_DENIED_ERROR/);
    assert.match(diagnostic, /1045/);
    assert.doesNotMatch(diagnostic, new RegExp(passwordSentinel));
    assert.doesNotMatch(diagnostic, new RegExp(jwtSentinel));
    assert.doesNotMatch(responseBody.message, /password|secret|access denied/i);
  } finally {
    if (originalPassword === undefined) delete process.env.DB_PASSWORD;
    else process.env.DB_PASSWORD = originalPassword;
    if (originalJwtSecret === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = originalJwtSecret;
  }
});

test('login rate limit returns JSON 429 after 10 attempts per 15 minutes', async (t) => {
  const execute = t.mock.method(pool, 'execute', async () => {
    throw new Error('Invalid login input must not query the database');
  });
  const query = t.mock.method(pool, 'query', async () => {
    throw new Error('Login attempts must not query the database');
  });

  for (let attempt = 1; attempt <= 10; attempt += 1) {
    const response = await send('POST', '/api/auth/login', {
      email: 'invalid',
      password: 'password',
    });
    assert.equal(response.status, 400);
  }

  const limited = await send('POST', '/api/auth/login', {
    email: 'invalid',
    password: 'password',
  });
  assert.equal(limited.status, 429);
  assert.deepEqual(await limited.json(), {
    success: false,
    message: 'Terlalu banyak percobaan autentikasi. Silakan coba lagi nanti.',
  });
  assert.equal(execute.mock.callCount(), 0);
  assert.equal(query.mock.callCount(), 0);

  const otherAuthRoute = await send('POST', '/api/auth/register', {});
  assert.equal(otherAuthRoute.status, 400);
});

test('register rate limit returns JSON 429 after 5 attempts per hour', async (t) => {
  const execute = t.mock.method(pool, 'execute', async () => {
    throw new Error('Invalid registration input must not query the database');
  });
  const query = t.mock.method(pool, 'query', async () => {
    throw new Error('Registration attempts must not query the database');
  });

  for (let attempt = 1; attempt <= 5; attempt += 1) {
    const response = await send('POST', '/api/auth/register', {});
    assert.equal(response.status, 400);
  }

  const limited = await send('POST', '/api/auth/register', {});
  assert.equal(limited.status, 429);
  assert.deepEqual(await limited.json(), {
    success: false,
    message: 'Terlalu banyak percobaan autentikasi. Silakan coba lagi nanti.',
  });
  assert.equal(execute.mock.callCount(), 0);
  assert.equal(query.mock.callCount(), 0);

  const profileRoute = await send('GET', '/api/profile');
  assert.equal(profileRoute.status, 401);
});
