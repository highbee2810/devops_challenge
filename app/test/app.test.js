'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');

let server;
let base;

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('GET /health returns 200 and status ok', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok' });
});

test('GET / returns service metadata', async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.service, 'devops-challenge-app');
  assert.ok(body.version);
});

test('GET /api/time returns an ISO timestamp', async () => {
  const body = await (await fetch(`${base}/api/time`)).json();
  assert.ok(!Number.isNaN(Date.parse(body.now)));
});

test('unknown routes return 404 JSON', async () => {
  const res = await fetch(`${base}/nope`);
  assert.equal(res.status, 404);
  assert.deepEqual(await res.json(), { error: 'not_found' });
});
