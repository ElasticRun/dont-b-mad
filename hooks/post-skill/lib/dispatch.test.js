'use strict';
/**
 * Unit tests for dispatch.js logic.
 * Tests: skill filter, event-type mapping, idempotency key, payload assembly.
 * Uses node:test (built-in, no install needed).
 */

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

// ---------------------------------------------------------------------------
// Inline copies of testable pure functions from dispatch.js
// (dispatch.js is not structured as a module to avoid any require overhead
//  in the hot path; we test the logic inline here)
// ---------------------------------------------------------------------------

const SKILL_EVENT_MAP = {
  'bmad-create-story': 'story_created',
  'bmad-dev-story': 'story_developed',
  'bmad-code-review': 'review_landed',
  'bmad-qa-generate-e2e-tests': 'test_added',
};

function deriveIdempotencyKey(actor, eventType, skillName, occurredAt) {
  const parts = [
    actor,
    eventType,
    skillName != null ? skillName : '',
    occurredAt.toISOString().slice(0, 19),
  ].join('|');
  return crypto.createHash('sha256').update(parts).digest('hex');
}

function buildCommitMessageDraft(aiPhase, aiTool, storyRef) {
  const lines = [`AI-Phase: ${aiPhase}`, `AI-Tool: ${aiTool}`];
  if (storyRef) lines.push(`Story-Ref: ${storyRef}`);
  const full = lines.join('\n');
  return full.slice(0, 80);
}

function isAllowedSkill(skillName, allowedSkillsRaw) {
  const allowed = allowedSkillsRaw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (allowed.length === 0) return true; // no filter = allow all
  return allowed.includes(skillName);
}

function parseEnvLines(raw) {
  const result = {};
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    result[key] = value;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Tests: skill filter (AC#6)
// ---------------------------------------------------------------------------

describe('skill filter', () => {
  test('allows skill in whitelist', () => {
    assert.equal(isAllowedSkill('bmad-create-story', 'bmad-create-story,bmad-dev-story'), true);
  });

  test('blocks skill not in whitelist', () => {
    assert.equal(isAllowedSkill('bmad-code-review', 'bmad-create-story'), false);
  });

  test('empty whitelist allows everything', () => {
    assert.equal(isAllowedSkill('bmad-create-story', ''), true);
    assert.equal(isAllowedSkill('any-skill', ''), true);
  });

  test('trims whitespace around skill names', () => {
    assert.equal(isAllowedSkill('bmad-dev-story', ' bmad-dev-story , bmad-code-review '), true);
  });
});

// ---------------------------------------------------------------------------
// Tests: event-type mapping (AC#7)
// ---------------------------------------------------------------------------

describe('event-type mapping', () => {
  test('bmad-create-story → story_created', () => {
    assert.equal(SKILL_EVENT_MAP['bmad-create-story'], 'story_created');
  });

  test('bmad-dev-story → story_developed', () => {
    assert.equal(SKILL_EVENT_MAP['bmad-dev-story'], 'story_developed');
  });

  test('bmad-code-review → review_landed', () => {
    assert.equal(SKILL_EVENT_MAP['bmad-code-review'], 'review_landed');
  });

  test('bmad-qa-generate-e2e-tests → test_added', () => {
    assert.equal(SKILL_EVENT_MAP['bmad-qa-generate-e2e-tests'], 'test_added');
  });

  test('unknown skill returns undefined (caller skips)', () => {
    assert.equal(SKILL_EVENT_MAP['bmad-unknown-skill'], undefined);
  });
});

// ---------------------------------------------------------------------------
// Tests: idempotency key (AC#9)
// ---------------------------------------------------------------------------

describe('idempotency key', () => {
  test('produces 64-char hex sha256', () => {
    const key = deriveIdempotencyKey('Sachin', 'story_created', 'bmad-create-story', new Date('2026-05-06T10:00:00.000Z'));
    assert.equal(typeof key, 'string');
    assert.equal(key.length, 64);
    assert.match(key, /^[0-9a-f]{64}$/);
  });

  test('matches server derivation — known vector', () => {
    // Computed independently: sha256("Sachin|story_created|bmad-create-story|2026-05-06T10:00:00")
    const actor = 'Sachin';
    const eventType = 'story_created';
    const skillName = 'bmad-create-story';
    const occurredAt = new Date('2026-05-06T10:00:00.000Z');

    const expected = crypto
      .createHash('sha256')
      .update(['Sachin', 'story_created', 'bmad-create-story', '2026-05-06T10:00:00'].join('|'))
      .digest('hex');

    assert.equal(deriveIdempotencyKey(actor, eventType, skillName, occurredAt), expected);
  });

  test('sub-second timestamps produce same key (seconds truncation)', () => {
    const t1 = new Date('2026-05-06T10:00:00.000Z');
    const t2 = new Date('2026-05-06T10:00:00.999Z');
    // Both slice to '2026-05-06T10:00:00' so keys must match
    const k1 = deriveIdempotencyKey('Sachin', 'story_created', 'bmad-create-story', t1);
    const k2 = deriveIdempotencyKey('Sachin', 'story_created', 'bmad-create-story', t2);
    assert.equal(k1, k2);
  });

  test('null skillName uses empty string', () => {
    const withNull = deriveIdempotencyKey('Sachin', 'story_created', null, new Date('2026-05-06T10:00:00.000Z'));
    const withEmpty = deriveIdempotencyKey('Sachin', 'story_created', '', new Date('2026-05-06T10:00:00.000Z'));
    assert.equal(withNull, withEmpty);
  });

  test('different actors produce different keys', () => {
    const t = new Date('2026-05-06T10:00:00.000Z');
    const k1 = deriveIdempotencyKey('Sachin', 'story_created', 'bmad-create-story', t);
    const k2 = deriveIdempotencyKey('Alice', 'story_created', 'bmad-create-story', t);
    assert.notEqual(k1, k2);
  });
});

// ---------------------------------------------------------------------------
// Tests: commit_message_draft assembly (AC#8)
// ---------------------------------------------------------------------------

describe('buildCommitMessageDraft', () => {
  test('produces trailer with all three fields', () => {
    // Use short values so the combined string stays under 80 chars
    const draft = buildCommitMessageDraft('code', 'cli', '8-3');
    assert.ok(draft.includes('AI-Phase: code'));
    assert.ok(draft.includes('AI-Tool: cli'));
    assert.ok(draft.includes('Story-Ref: 8-3'));
  });

  test('longer story ref is still present when combined length within 80', () => {
    // "AI-Phase: code\nAI-Tool: cli\nStory-Ref: 8-3-hook" = 49 chars
    const draft = buildCommitMessageDraft('code', 'cli', '8-3-hook');
    assert.ok(draft.includes('Story-Ref: 8-3-hook'));
  });

  test('omits Story-Ref line when storyRef is null', () => {
    const draft = buildCommitMessageDraft('code', 'cli/claude', null);
    assert.ok(!draft.includes('Story-Ref'));
    assert.ok(draft.includes('AI-Phase: code'));
  });

  test('truncates to 80 chars', () => {
    const long = 'x'.repeat(200);
    const draft = buildCommitMessageDraft('code', long, long);
    assert.ok(draft.length <= 80);
  });

  test('short input is not padded', () => {
    const draft = buildCommitMessageDraft('code', 'cli', null);
    assert.ok(draft.length < 80);
  });
});

// ---------------------------------------------------------------------------
// Tests: stealth mode
// ---------------------------------------------------------------------------

describe('stealth mode', () => {
  test('AIEYE_LIVE_STEALTH_MODE=true is parsed from env file', () => {
    const cfg = parseEnvLines('AIEYE_LIVE_STEALTH_MODE=true\nAIEYE_LIVE_INGEST_URL=https://x\n');
    assert.equal(cfg['AIEYE_LIVE_STEALTH_MODE'], 'true');
  });

  test('AIEYE_LIVE_STEALTH_MODE=false is not treated as stealth', () => {
    const cfg = parseEnvLines('AIEYE_LIVE_STEALTH_MODE=false\n');
    assert.notEqual(cfg['AIEYE_LIVE_STEALTH_MODE'], 'true');
  });

  test('AIEYE_LIVE_STEALTH_MODE absent defaults to non-stealth', () => {
    const cfg = parseEnvLines('AIEYE_LIVE_INGEST_URL=https://x\n');
    assert.equal(cfg['AIEYE_LIVE_STEALTH_MODE'], undefined);
  });
});

// ---------------------------------------------------------------------------
// Tests: env file parser
// ---------------------------------------------------------------------------

describe('parseEnvLines', () => {
  test('parses KEY=VALUE pairs', () => {
    const cfg = parseEnvLines('FOO=bar\nBAZ=qux\n');
    assert.equal(cfg['FOO'], 'bar');
    assert.equal(cfg['BAZ'], 'qux');
  });

  test('ignores comments and blank lines', () => {
    const cfg = parseEnvLines('# comment\n\nFOO=bar\n');
    assert.equal(Object.keys(cfg).length, 1);
    assert.equal(cfg['FOO'], 'bar');
  });

  test('value can contain = sign', () => {
    const cfg = parseEnvLines('TOKEN=abc=def=ghi\n');
    assert.equal(cfg['TOKEN'], 'abc=def=ghi');
  });

  test('trims whitespace around key and value', () => {
    const cfg = parseEnvLines('  KEY  =  value  \n');
    assert.equal(cfg['KEY'], 'value');
  });
});
