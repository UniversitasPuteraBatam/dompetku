const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { after, before, test } = require('node:test');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'dompetku-test-only-secret';
process.env.UPLOADS_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'dompetku-uploads-'));

const { app, pool, PROFILE_PHOTO_DIR } = require('../index');

const token = jwt.sign({ id: 7 }, process.env.JWT_SECRET);
const pngBytes = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
]);
const user = { id: 7, name: 'User', email: 'user@example.com' };

let server;
let baseUrl;

before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  fs.mkdirSync(PROFILE_PHOTO_DIR, { recursive: true });
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
  fs.rmSync(process.env.UPLOADS_DIR, { recursive: true, force: true });
});

function uploadPhoto(bytes, { authorization = token, field = 'photo' } = {}) {
  const form = new FormData();
  if (bytes) form.append(field, new Blob([bytes]), 'photo.bin');
  const headers = {};
  if (authorization) headers.Authorization = `Bearer ${authorization}`;
  return fetch(`${baseUrl}/api/profile/photo`, {
    method: 'POST',
    headers,
    body: form,
  });
}

function mockUserRow(t, profilePhoto) {
  return t.mock.method(pool, 'execute', async (sql) => {
    if (sql.startsWith('UPDATE')) return [{ affectedRows: 1 }, []];
    return [[{ ...user, profile_photo: profilePhoto }], []];
  });
}

test('upload stores the photo, saves its path and serves the file', async (t) => {
  const execute = mockUserRow(t, null);

  const response = await uploadPhoto(pngBytes);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.success, true);
  assert.match(body.data.profile_photo, /^\/uploads\/profile\/7-\d+-[0-9a-f]{12}\.png$/);
  assert.equal(body.data.name, 'User');

  const update = execute.mock.calls.find((call) =>
    call.arguments[0].startsWith('UPDATE'),
  );
  assert.deepEqual(update.arguments[1], [body.data.profile_photo, 7]);

  const served = await fetch(`${baseUrl}${body.data.profile_photo}`);
  assert.equal(served.status, 200);
  assert.deepEqual(Buffer.from(await served.arrayBuffer()), pngBytes);
});

test('upload replaces and removes the previous photo of the same user', async (t) => {
  const oldFile = '7-1-aaaaaaaaaaaa.png';
  fs.writeFileSync(path.join(PROFILE_PHOTO_DIR, oldFile), pngBytes);
  mockUserRow(t, `/uploads/profile/${oldFile}`);

  const response = await uploadPhoto(pngBytes);

  assert.equal(response.status, 200);
  assert.equal(fs.existsSync(path.join(PROFILE_PHOTO_DIR, oldFile)), false);
});

test('upload never removes a file that belongs to another user', async (t) => {
  const otherUserFile = '8-1-bbbbbbbbbbbb.png';
  fs.writeFileSync(path.join(PROFILE_PHOTO_DIR, otherUserFile), pngBytes);
  mockUserRow(t, `/uploads/profile/${otherUserFile}`);

  const response = await uploadPhoto(pngBytes);

  assert.equal(response.status, 200);
  assert.equal(fs.existsSync(path.join(PROFILE_PHOTO_DIR, otherUserFile)), true);
});

for (const [label, bytes, status] of [
  ['a file that is not an image', Buffer.from('<?php echo 1; ?>'), 400],
  ['a photo over 2 MB', Buffer.concat([pngBytes, Buffer.alloc(2 * 1024 * 1024)]), 413],
  ['a request without a photo', null, 400],
]) {
  test(`upload rejects ${label} before querying MySQL`, async (t) => {
    const execute = t.mock.method(pool, 'execute', async () => {
      throw new Error('Database must not be called for invalid uploads');
    });

    const response = await uploadPhoto(bytes);

    assert.equal(response.status, status);
    assert.equal((await response.json()).success, false);
    assert.equal(execute.mock.callCount(), 0);
  });
}

test('upload requires a login token', async () => {
  const response = await uploadPhoto(pngBytes, { authorization: null });

  assert.equal(response.status, 401);
});

test('delete clears the saved path and removes the file', async (t) => {
  const currentFile = '7-2-cccccccccccc.png';
  fs.writeFileSync(path.join(PROFILE_PHOTO_DIR, currentFile), pngBytes);
  const execute = mockUserRow(t, `/uploads/profile/${currentFile}`);

  const response = await fetch(`${baseUrl}/api/profile/photo`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.data.profile_photo, null);
  assert.equal(fs.existsSync(path.join(PROFILE_PHOTO_DIR, currentFile)), false);
  assert.ok(
    execute.mock.calls.some(
      (call) => call.arguments[0] === 'UPDATE users SET profile_photo = NULL WHERE id = ?',
    ),
  );
});

test('profile update without profile_photo keeps the current photo', async (t) => {
  const execute = mockUserRow(t, '/uploads/profile/7-3-dddddddddddd.png');

  const response = await fetch(`${baseUrl}/api/profile`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ name: 'Nama Baru' }),
  });

  assert.equal(response.status, 200);
  const update = execute.mock.calls.find((call) =>
    call.arguments[0].startsWith('UPDATE'),
  );
  assert.equal(update.arguments[0], 'UPDATE users SET name = ? WHERE id = ?');
  assert.deepEqual(update.arguments[1], ['Nama Baru', 7]);
});
