const assert = require('node:assert/strict');
const { after, before, beforeEach, test } = require('node:test');
const jwt = require('jsonwebtoken');
const { ipKeyGenerator } = require('express-rate-limit');

process.env.JWT_SECRET = 'dompetku-test-only-secret';

const {
  app,
  loginRateLimiter,
  pool,
  registerRateLimiter,
  validateAmount,
} = require('../index');
const localRateLimitKey = ipKeyGenerator('::ffff:127.0.0.1');

const MAX_AMOUNT = 9999999999999;
const validTransaction = {
  type: 'expense',
  category: 'Makanan',
  amount: 35000,
  description: 'Makan malam',
  transaction_date: '2026-10-10 12:30:00',
};
const token = jwt.sign({ id: 7 }, process.env.JWT_SECRET);

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

function mockExecute(t, implementation) {
  return t.mock.method(pool, 'execute', implementation);
}

async function send(method, path, body, { authorization = token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (authorization) headers.Authorization = `Bearer ${authorization}`;
  return fetch(`${baseUrl}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

test('amount validation accepts positive database-safe rupiah integers only', () => {
  assert.equal(validateAmount(1), true);
  assert.equal(validateAmount(MAX_AMOUNT), true);
  for (const amount of [
    0,
    -1,
    1.5,
    MAX_AMOUNT + 1,
    Number.MAX_SAFE_INTEGER,
    NaN,
    Infinity,
    -Infinity,
    '1000',
    null,
  ]) {
    assert.equal(validateAmount(amount), false, `reject amount ${amount}`);
  }
});

test('register accepts name and email at active schema limits', async (t) => {
  const execute = mockExecute(t, async (sql) => {
    if (sql.startsWith('SELECT')) return [[], []];
    return [{ insertId: 11 }, []];
  });
  const name = 'N'.repeat(100);
  const email = `${'a'.repeat(138)}@example.com`;
  assert.equal([...email].length, 150);

  const response = await send('POST', '/api/auth/register', {
    name,
    email,
    password: 'p'.repeat(72),
  });

  assert.equal(response.status, 201);
  assert.equal((await response.json()).data.name, name);
  assert.equal(execute.mock.callCount(), 2);
});

for (const [label, body] of [
  ['name over 100 characters', {
    name: 'N'.repeat(101),
    email: 'user@example.com',
    password: 'abcdef',
  }],
  ['email with invalid format', {
    name: 'User',
    email: 'not-an-email',
    password: 'abcdef',
  }],
  ['email over 150 characters', {
    name: 'User',
    email: `${'a'.repeat(139)}@example.com`,
    password: 'abcdef',
  }],
  ['password shorter than six characters', {
    name: 'User',
    email: 'user@example.com',
    password: 'abcde',
  }],
  ['password longer than bcrypt 72-byte limit', {
    name: 'User',
    email: 'user@example.com',
    password: 'p'.repeat(73),
  }],
]) {
  test(`register rejects ${label} before querying MySQL`, async (t) => {
    const execute = mockExecute(t, async () => {
      throw new Error('Database must not be called for invalid input');
    });
    const response = await send('POST', '/api/auth/register', body);

    assert.equal(response.status, 400);
    assert.equal((await response.json()).success, false);
    assert.equal(execute.mock.callCount(), 0);
  });
}

test('profile update accepts fields at active schema limits', async (t) => {
  const name = 'N'.repeat(100);
  const profilePhoto = 'p'.repeat(255);
  const execute = mockExecute(t, async (sql) => {
    if (sql.startsWith('UPDATE')) return [{ affectedRows: 1 }, []];
    return [[{ id: 7, name, email: 'user@example.com', profile_photo: profilePhoto }], []];
  });

  const response = await send('PUT', '/api/profile', { name, profile_photo: profilePhoto });

  assert.equal(response.status, 200);
  assert.equal((await response.json()).data.profile_photo, profilePhoto);
  assert.equal(execute.mock.callCount(), 2);
});

for (const [label, body] of [
  ['name over 100 characters', { name: 'N'.repeat(101) }],
  ['profile photo over 255 characters', {
    name: 'User',
    profile_photo: 'p'.repeat(256),
  }],
  ['profile photo with unsupported value type', {
    name: 'User',
    profile_photo: 42,
  }],
]) {
  test(`profile update rejects ${label} before querying MySQL`, async (t) => {
    const execute = mockExecute(t, async () => {
      throw new Error('Database must not be called for invalid input');
    });
    const response = await send('PUT', '/api/profile', body);

    assert.equal(response.status, 400);
    assert.equal((await response.json()).success, false);
    assert.equal(execute.mock.callCount(), 0);
  });
}

test('POST transaction accepts database-safe amount and maximum text lengths', async (t) => {
  const execute = mockExecute(t, async () => [{ insertId: 21 }, []]);
  const body = {
    ...validTransaction,
    category: 'C'.repeat(100),
    amount: MAX_AMOUNT,
    description: 'D'.repeat(255),
  };

  const response = await send('POST', '/api/transactions', body);

  assert.equal(response.status, 201);
  assert.equal((await response.json()).data.amount, MAX_AMOUNT);
  assert.equal(execute.mock.callCount(), 1);
});

test('PUT transaction accepts the same amount and text limits as POST', async (t) => {
  const body = {
    ...validTransaction,
    category: 'C'.repeat(100),
    amount: MAX_AMOUNT,
    description: 'D'.repeat(255),
  };
  const execute = mockExecute(t, async (sql) => {
    if (sql.startsWith('UPDATE')) return [{ affectedRows: 1 }, []];
    return [[{
      id: 21,
      user_id: 7,
      ...body,
    }], []];
  });

  const response = await send('PUT', '/api/transactions/21', body);

  assert.equal(response.status, 200);
  assert.equal((await response.json()).data.amount, MAX_AMOUNT);
  assert.equal(execute.mock.callCount(), 2);
});

for (const method of ['POST', 'PUT']) {
  const path = method === 'POST' ? '/api/transactions' : '/api/transactions/21';
  for (const [label, amount] of [
    ['decimal', 1.5],
    ['zero', 0],
    ['negative', -1],
    ['above database capacity', MAX_AMOUNT + 1],
    ['string', '1000'],
    ['null', null],
  ]) {
    test(`${method} transaction rejects ${label} amount before querying MySQL`, async (t) => {
      const execute = mockExecute(t, async () => {
        throw new Error('Database must not be called for invalid input');
      });
      const response = await send(method, path, { ...validTransaction, amount });

      assert.equal(response.status, 400);
      assert.match((await response.json()).message, /Amount/);
      assert.equal(execute.mock.callCount(), 0);
    });
  }

  for (const [label, body] of [
    ['category over 100 characters', {
      ...validTransaction,
      category: 'C'.repeat(101),
    }],
    ['description over 255 characters', {
      ...validTransaction,
      description: 'D'.repeat(256),
    }],
    ['invalid transaction type', {
      ...validTransaction,
      type: 'transfer',
    }],
    ['invalid transaction date', {
      ...validTransaction,
      transaction_date: '2026-02-30 12:30:00',
    }],
  ]) {
    test(`${method} transaction rejects ${label} before querying MySQL`, async (t) => {
      const execute = mockExecute(t, async () => {
        throw new Error('Database must not be called for invalid input');
      });
      const response = await send(method, path, body);

      assert.equal(response.status, 400);
      assert.equal((await response.json()).success, false);
      assert.equal(execute.mock.callCount(), 0);
    });
  }
}

test('malformed JSON returns a clear 400 response', async () => {
  const response = await fetch(`${baseUrl}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{"name":',
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    success: false,
    message: 'Format JSON request tidak valid',
  });
});
