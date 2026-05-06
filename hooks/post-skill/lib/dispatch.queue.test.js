'use strict';
/**
 * Tests for story 8.4 queue/retry logic in dispatch.js.
 * Uses node:test (built-in) and a temp directory to avoid touching real ~/.claude.
 */

const { test, describe, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

// ---------------------------------------------------------------------------
// Inline copies of the queue helpers from dispatch.js so we can unit-test
// them in isolation without spawning the full process.
// ---------------------------------------------------------------------------

const QUEUE_FLUSH_LIMIT = 100;

function makeQueueHelpers(queueFile, queueFileTmp) {
  // Mirrors queueRead._surplus state per instance
  let surplus = [];

  function queueAppend(payload) {
    fs.appendFileSync(queueFile, JSON.stringify(payload) + '\n', 'utf8');
  }

  function queueRead() {
    let raw;
    try {
      raw = fs.readFileSync(queueFile, 'utf8');
    } catch (err) {
      if (err.code === 'ENOENT') { surplus = []; return []; }
      surplus = [];
      return [];
    }

    const lines = raw.split('\n').filter((l) => l.trim().length > 0);
    const batch = lines.slice(0, QUEUE_FLUSH_LIMIT);
    surplus = lines.slice(QUEUE_FLUSH_LIMIT);

    const payloads = [];
    for (const line of batch) {
      try {
        payloads.push({ payload: JSON.parse(line), raw: line });
      } catch (_) {
        // drop malformed
      }
    }
    return payloads;
  }

  function queueRewrite(failedLines) {
    const allLines = [...failedLines, ...surplus];
    if (allLines.length === 0) {
      try { fs.unlinkSync(queueFile); } catch (_) {}
      return;
    }
    const content = allLines.join('\n') + '\n';
    fs.writeFileSync(queueFileTmp, content, 'utf8');
    fs.renameSync(queueFileTmp, queueFile);
  }

  async function flushQueue(postJSON, ingestUrl, token) {
    const entries = queueRead();
    if (entries.length === 0) return;

    const failed = [];

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      let result;
      try {
        result = await postJSON(ingestUrl, entry.payload, token);
      } catch (_) {
        for (let j = i; j < entries.length; j++) failed.push(entries[j].raw);
        break;
      }

      if (result.status === 401) {
        // drop — token revoked
        continue;
      }

      if (result.status < 200 || result.status >= 300) {
        for (let j = i; j < entries.length; j++) failed.push(entries[j].raw);
        break;
      }
      // 2xx — delivered
    }

    queueRewrite(failed);
  }

  return { queueAppend, queueRead, queueRewrite, flushQueue };
}

// ---------------------------------------------------------------------------
// Test setup: fresh temp dir per test
// ---------------------------------------------------------------------------

let tmpDir;
let queueFile;
let queueFileTmp;
let helpers;

function setup() {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'aieye-queue-test-'));
  queueFile = path.join(tmpDir, 'aieye-live-queue.jsonl');
  queueFileTmp = queueFile + '.tmp';
  helpers = makeQueueHelpers(queueFile, queueFileTmp);
}

function teardown() {
  try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch (_) {}
}

// ---------------------------------------------------------------------------
// AC#1 — queue append on network error / 5xx
// ---------------------------------------------------------------------------

describe('queueAppend (AC#1, AC#6)', () => {
  beforeEach(setup);
  afterEach(teardown);

  test('appends JSON line to queue file', () => {
    const p = { actor: 'Alice', event_type: 'story_created', idempotency_key: 'k1' };
    helpers.queueAppend(p);
    const content = fs.readFileSync(queueFile, 'utf8');
    assert.ok(content.includes('"actor":"Alice"'));
    assert.ok(content.endsWith('\n'));
  });

  test('creates queue file if absent (AC#6)', () => {
    assert.ok(!fs.existsSync(queueFile));
    helpers.queueAppend({ event_type: 'story_created' });
    assert.ok(fs.existsSync(queueFile));
  });

  test('multiple appends produce multiple lines', () => {
    helpers.queueAppend({ n: 1 });
    helpers.queueAppend({ n: 2 });
    helpers.queueAppend({ n: 3 });
    const lines = fs.readFileSync(queueFile, 'utf8').trim().split('\n');
    assert.equal(lines.length, 3);
    assert.equal(JSON.parse(lines[0]).n, 1);
    assert.equal(JSON.parse(lines[2]).n, 3);
  });
});

// ---------------------------------------------------------------------------
// AC#3 — queue read (up to 100 oldest-first)
// ---------------------------------------------------------------------------

describe('queueRead (AC#3)', () => {
  beforeEach(setup);
  afterEach(teardown);

  test('returns empty array when file missing', () => {
    const entries = helpers.queueRead();
    assert.deepEqual(entries, []);
  });

  test('returns parsed payloads in file order', () => {
    fs.writeFileSync(queueFile, '{"n":1}\n{"n":2}\n{"n":3}\n', 'utf8');
    const entries = helpers.queueRead();
    assert.equal(entries.length, 3);
    assert.equal(entries[0].payload.n, 1);
    assert.equal(entries[2].payload.n, 3);
  });

  test('reads at most 100 lines', () => {
    const lines = Array.from({ length: 150 }, (_, i) => JSON.stringify({ n: i }));
    fs.writeFileSync(queueFile, lines.join('\n') + '\n', 'utf8');
    const entries = helpers.queueRead();
    assert.equal(entries.length, 100);
    assert.equal(entries[0].payload.n, 0);
    assert.equal(entries[99].payload.n, 99);
  });
});

// ---------------------------------------------------------------------------
// AC#3 / AC#4 — queueRewrite atomic temp+rename
// ---------------------------------------------------------------------------

describe('queueRewrite (AC#3, AC#4)', () => {
  beforeEach(setup);
  afterEach(teardown);

  test('rewrites queue with only failed lines', () => {
    fs.writeFileSync(queueFile, '{"n":1}\n{"n":2}\n{"n":3}\n', 'utf8');
    helpers.queueRead(); // populate surplus state
    // Simulate: n=1 succeeded, n=2 and n=3 failed
    helpers.queueRewrite(['{"n":2}', '{"n":3}']);
    const lines = fs.readFileSync(queueFile, 'utf8').trim().split('\n');
    assert.equal(lines.length, 2);
    assert.equal(JSON.parse(lines[0]).n, 2);
  });

  test('removes queue file when all entries delivered', () => {
    fs.writeFileSync(queueFile, '{"n":1}\n', 'utf8');
    helpers.queueRead();
    helpers.queueRewrite([]); // all succeeded
    assert.ok(!fs.existsSync(queueFile));
  });

  test('temp file is not left behind after successful rename', () => {
    fs.writeFileSync(queueFile, '{"n":1}\n', 'utf8');
    helpers.queueRead();
    helpers.queueRewrite(['{"n":1}']);
    assert.ok(!fs.existsSync(queueFileTmp));
  });

  test('surplus lines beyond batch are preserved after rewrite', () => {
    // 102 lines; batch = 100, surplus = 2
    const lines = Array.from({ length: 102 }, (_, i) => JSON.stringify({ n: i }));
    fs.writeFileSync(queueFile, lines.join('\n') + '\n', 'utf8');
    helpers.queueRead(); // sets surplus to lines 100,101
    helpers.queueRewrite([]); // batch all delivered
    // Only surplus lines 100 and 101 should remain
    const remaining = fs.readFileSync(queueFile, 'utf8').trim().split('\n');
    assert.equal(remaining.length, 2);
    assert.equal(JSON.parse(remaining[0]).n, 100);
    assert.equal(JSON.parse(remaining[1]).n, 101);
  });
});

// ---------------------------------------------------------------------------
// AC#3, AC#5 — flushQueue integration: POST each in order, rewrite survivors
// ---------------------------------------------------------------------------

describe('flushQueue (AC#3, AC#5)', () => {
  beforeEach(setup);
  afterEach(teardown);

  test('all succeed — queue file removed', async () => {
    fs.writeFileSync(queueFile, '{"n":1}\n{"n":2}\n', 'utf8');
    const posts = [];
    const mockPost = async (url, payload) => {
      posts.push(payload.n);
      return { status: 200 };
    };
    await helpers.flushQueue(mockPost, 'http://localhost/ingest', 'tok');
    assert.deepEqual(posts, [1, 2]);
    assert.ok(!fs.existsSync(queueFile));
  });

  test('POSTs in oldest-first order (AC#5)', async () => {
    const payloads = Array.from({ length: 5 }, (_, i) => ({ n: i }));
    fs.writeFileSync(queueFile, payloads.map((p) => JSON.stringify(p)).join('\n') + '\n', 'utf8');
    const order = [];
    const mockPost = async (url, payload) => { order.push(payload.n); return { status: 201 }; };
    await helpers.flushQueue(mockPost, 'http://x', 'tok');
    assert.deepEqual(order, [0, 1, 2, 3, 4]);
  });

  test('stops at first 5xx, preserves that entry and remainder', async () => {
    fs.writeFileSync(queueFile, '{"n":1}\n{"n":2}\n{"n":3}\n', 'utf8');
    const mockPost = async (url, payload) => {
      if (payload.n === 2) return { status: 503 };
      return { status: 200 };
    };
    await helpers.flushQueue(mockPost, 'http://x', 'tok');
    const lines = fs.readFileSync(queueFile, 'utf8').trim().split('\n');
    // n=1 succeeded, n=2 and n=3 remain
    assert.equal(lines.length, 2);
    assert.equal(JSON.parse(lines[0]).n, 2);
    assert.equal(JSON.parse(lines[1]).n, 3);
  });

  test('network error: preserves failed entry and remainder', async () => {
    fs.writeFileSync(queueFile, '{"n":1}\n{"n":2}\n', 'utf8');
    const mockPost = async (url, payload) => {
      if (payload.n === 1) throw new Error('ECONNREFUSED');
      return { status: 200 };
    };
    await helpers.flushQueue(mockPost, 'http://x', 'tok');
    const lines = fs.readFileSync(queueFile, 'utf8').trim().split('\n');
    assert.equal(lines.length, 2);
    assert.equal(JSON.parse(lines[0]).n, 1);
    assert.equal(JSON.parse(lines[1]).n, 2);
  });

  test('empty queue — no POST made', async () => {
    let called = false;
    const mockPost = async () => { called = true; return { status: 200 }; };
    await helpers.flushQueue(mockPost, 'http://x', 'tok');
    assert.ok(!called);
  });
});

// ---------------------------------------------------------------------------
// AC#2 — 401 drop logic in flushQueue
// ---------------------------------------------------------------------------

describe('401 drop in flushQueue (AC#2)', () => {
  beforeEach(setup);
  afterEach(teardown);

  test('401 entry is dropped, others still delivered', async () => {
    fs.writeFileSync(queueFile, '{"n":1}\n{"n":2}\n{"n":3}\n', 'utf8');
    const delivered = [];
    const mockPost = async (url, payload) => {
      if (payload.n === 2) return { status: 401 };
      delivered.push(payload.n);
      return { status: 200 };
    };
    await helpers.flushQueue(mockPost, 'http://x', 'tok');
    // n=2 dropped (401), n=1 and n=3 delivered
    assert.deepEqual(delivered, [1, 3]);
    assert.ok(!fs.existsSync(queueFile));
  });

  test('401 on all entries empties queue', async () => {
    fs.writeFileSync(queueFile, '{"n":1}\n{"n":2}\n', 'utf8');
    const mockPost = async () => ({ status: 401 });
    await helpers.flushQueue(mockPost, 'http://x', 'tok');
    assert.ok(!fs.existsSync(queueFile));
  });
});
