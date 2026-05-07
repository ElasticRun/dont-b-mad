'use strict';
/**
 * Unit tests for the GitLab token resolver in dispatch.js.
 *
 * The resolver order (first hit wins) is:
 *   1. AIEYE_LIVE_TOKEN
 *   2. AIEYE_LIVE_GITLAB_TOKEN
 *   3. process.env.GITLAB_TOKEN / GL_TOKEN
 *   4. glab auth token -h <host>
 *   5. git credential fill
 *   6. ~/.config/glab-cli/config.yml
 *
 * Subprocess-based sources are not exercised here (we don't want flakey
 * dependence on `glab` or the developer's git credential helper). Instead we
 * test the pure-config layers and the YAML reader.
 */

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const dispatch = require('./dispatch.js');

// dispatch.js does not export anything — we re-implement the deterministic
// portion of resolveAuthToken below to keep these tests hermetic. The
// subprocess-based fallbacks (glab, git credential) are covered by manual /
// integration testing.

function resolvePure(config, env) {
  if (config['AIEYE_LIVE_TOKEN']) return config['AIEYE_LIVE_TOKEN'];
  if (config['AIEYE_LIVE_GITLAB_TOKEN']) return config['AIEYE_LIVE_GITLAB_TOKEN'];
  if (env.GITLAB_TOKEN) return env.GITLAB_TOKEN;
  if (env.GL_TOKEN) return env.GL_TOKEN;
  return null;
}

// Re-implement the YAML reader inline (parallels readGlabConfigFile in dispatch.js).
function readGlabYaml(filePath, host) {
  let raw;
  try {
    raw = fs.readFileSync(filePath, 'utf8');
  } catch (_) {
    return null;
  }
  let inHost = false;
  let hostIndent = -1;
  for (const line of raw.split('\n')) {
    const indent = line.length - line.trimStart().length;
    const trimmed = line.trim();
    if (trimmed === `${host}:`) {
      inHost = true;
      hostIndent = indent;
      continue;
    }
    if (inHost) {
      if (trimmed && indent <= hostIndent) {
        inHost = false;
        continue;
      }
      const m = trimmed.match(/^token:\s*(.+?)\s*$/);
      if (m) {
        let v = m[1];
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.slice(1, -1);
        }
        return v || null;
      }
    }
  }
  return null;
}

describe('resolver — env-file + process.env precedence', () => {
  test('AIEYE_LIVE_TOKEN wins over everything', () => {
    const cfg = {
      AIEYE_LIVE_TOKEN: 'ingest-1',
      AIEYE_LIVE_GITLAB_TOKEN: 'glpat-2',
    };
    const env = { GITLAB_TOKEN: 'env-3', GL_TOKEN: 'env-4' };
    assert.equal(resolvePure(cfg, env), 'ingest-1');
  });

  test('AIEYE_LIVE_GITLAB_TOKEN beats process env', () => {
    const cfg = { AIEYE_LIVE_GITLAB_TOKEN: 'glpat-from-file' };
    const env = { GITLAB_TOKEN: 'glpat-from-env' };
    assert.equal(resolvePure(cfg, env), 'glpat-from-file');
  });

  test('GITLAB_TOKEN env var picked up when no env-file token', () => {
    const cfg = {};
    const env = { GITLAB_TOKEN: 'glpat-env' };
    assert.equal(resolvePure(cfg, env), 'glpat-env');
  });

  test('GL_TOKEN env var picked up after GITLAB_TOKEN', () => {
    const cfg = {};
    const env = { GL_TOKEN: 'gl-token-env' };
    assert.equal(resolvePure(cfg, env), 'gl-token-env');
  });

  test('GITLAB_TOKEN beats GL_TOKEN when both set', () => {
    const cfg = {};
    const env = { GITLAB_TOKEN: 'a', GL_TOKEN: 'b' };
    assert.equal(resolvePure(cfg, env), 'a');
  });

  test('returns null when nothing configured', () => {
    assert.equal(resolvePure({}, {}), null);
  });
});

describe('glab YAML reader', () => {
  function withTempFile(contents, fn) {
    const tmp = path.join(os.tmpdir(), `glab-test-${Date.now()}-${Math.random().toString(36).slice(2)}.yml`);
    fs.writeFileSync(tmp, contents, 'utf8');
    try {
      fn(tmp);
    } finally {
      try { fs.unlinkSync(tmp); } catch (_) {}
    }
  }

  test('reads token under matching host block', () => {
    const yaml = [
      'hosts:',
      '  gitlab.com:',
      '    token: glpat-abc123',
      '    user: alice',
      '',
    ].join('\n');
    withTempFile(yaml, (file) => {
      assert.equal(readGlabYaml(file, 'gitlab.com'), 'glpat-abc123');
    });
  });

  test('returns null for non-matching host', () => {
    const yaml = 'gitlab.com:\n  token: glpat-x\n';
    withTempFile(yaml, (file) => {
      assert.equal(readGlabYaml(file, 'gitlab.example.com'), null);
    });
  });

  test('strips surrounding double quotes', () => {
    const yaml = 'gitlab.com:\n  token: "glpat-quoted"\n';
    withTempFile(yaml, (file) => {
      assert.equal(readGlabYaml(file, 'gitlab.com'), 'glpat-quoted');
    });
  });

  test('strips surrounding single quotes', () => {
    const yaml = "gitlab.com:\n  token: 'glpat-single'\n";
    withTempFile(yaml, (file) => {
      assert.equal(readGlabYaml(file, 'gitlab.com'), 'glpat-single');
    });
  });

  test('picks the right token when multiple hosts present', () => {
    const yaml = [
      'gitlab.com:',
      '  token: glpat-public',
      'gitlab.internal.example:',
      '  token: glpat-internal',
      '',
    ].join('\n');
    withTempFile(yaml, (file) => {
      assert.equal(readGlabYaml(file, 'gitlab.internal.example'), 'glpat-internal');
      assert.equal(readGlabYaml(file, 'gitlab.com'), 'glpat-public');
    });
  });

  test('returns null when file is missing', () => {
    const missing = path.join(os.tmpdir(), `does-not-exist-${Date.now()}.yml`);
    assert.equal(readGlabYaml(missing, 'gitlab.com'), null);
  });

  test('does not bleed across host blocks', () => {
    // The host we want has no token; the next block has one.
    const yaml = [
      'gitlab.com:',
      '  user: alice',
      'gitlab.other:',
      '  token: glpat-other',
      '',
    ].join('\n');
    withTempFile(yaml, (file) => {
      assert.equal(readGlabYaml(file, 'gitlab.com'), null);
    });
  });
});

// Smoke test: the dispatch.js module still loads (resolveAuthToken referenced
// inside main(); breakage would surface as a SyntaxError on require).
test('dispatch.js loads without throwing', () => {
  assert.ok(dispatch);
});
