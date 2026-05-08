'use strict';
/**
 * dispatch.js — AIEye Live hook dispatcher
 *
 * Reads ~/.claude/aieye-live.env for actor / filters; POSTs to a fixed ingest URL.
 * Bearer token always comes from `git credential fill` for the GitLab host.
 * No npm dependencies — only Node.js built-ins.
 *
 * Called by bin/aieye-live-hook in a background subshell with a 2-second ceiling.
 *
 * Queue behaviour (story 8.4):
 *   - On network error or 5xx: append payload to ~/.claude/aieye-live-queue.jsonl
 *   - On 401: drop event, log to stderr (token revoked — retrying forever is pointless)
 *   - On each invocation: flush up to 100 queued events before the current one
 *   - Atomic rewrite via rename-to-replace (POSIX rename(2) is atomic at the fs level;
 *     concurrent processes each overwrite; last rename wins — server idempotency keys
 *     deduplicate any double-delivery in the race window)
 */

const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const http = require('node:http');
const crypto = require('node:crypto');
const os = require('node:os');
const { spawnSync } = require('node:child_process');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const ENV_FILE = path.join(os.homedir(), '.claude', 'aieye-live.env');
const QUEUE_FILE = path.join(os.homedir(), '.claude', 'aieye-live-queue.jsonl');
const QUEUE_FILE_TMP = QUEUE_FILE + '.tmp';
const QUEUE_FLUSH_LIMIT = 100;

/** Fixed AIEye Live ingest endpoint (not configurable). */
const INGEST_URL = 'https://doha-aieye.elasticrun.in/api/events';

/** GitLab host for `git credential fill` only (not configurable). */
const GITLAB_CREDENTIAL_HOST = 'engg.elasticrun.in';

/** Skill name → event_type mapping (AC#7) */
const SKILL_EVENT_MAP = {
  'bmad-create-story': 'story_created',
  'bmad-dev-story': 'story_developed',
  'bmad-code-review': 'review_landed',
  'bmad-qa-generate-e2e-tests': 'test_added',
};

// ---------------------------------------------------------------------------
// Config reader (AC#5)
// ---------------------------------------------------------------------------

/**
 * Parse a KEY=VALUE env file. Lines starting with # are comments.
 * Returns an object of key/value pairs.
 */
function parseEnvFile(filePath) {
  const result = {};
  let raw;
  try {
    raw = fs.readFileSync(filePath, 'utf8');
  } catch (err) {
    if (err.code === 'ENOENT') {
      // Missing file — skip silently (AC#5)
      return null;
    }
    throw err;
  }

  // Check permissions — warn if world-readable (AC#5)
  try {
    const stat = fs.statSync(filePath);
    const mode = stat.mode & 0o777;
    if (mode & 0o004) {
      process.stderr.write(
        `[aieye-live-hook] WARNING: ${filePath} is world-readable (mode ${mode.toString(8)}). ` +
        'Set permissions to 600: chmod 600 ~/.claude/aieye-live.env\n'
      );
    }
  } catch (_) {
    // Ignore stat errors
  }

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
// GitLab token via git credential only
// ---------------------------------------------------------------------------
// All subprocess calls are tightly time-bounded (the hook has a 2s ceiling).

const SUBPROCESS_TIMEOUT_MS = 600;

/** Run `git credential fill` for <host> and return the password, or null. */
function readGitCredential(host) {
  try {
    const stdin = `protocol=https\nhost=${host}\n\n`;
    const res = spawnSync('git', ['credential', 'fill'], {
      input: stdin,
      timeout: SUBPROCESS_TIMEOUT_MS,
      encoding: 'utf8',
    });
    if (res.status !== 0) return null;
    for (const line of (res.stdout || '').split('\n')) {
      if (line.startsWith('password=')) {
        const v = line.slice('password='.length).trim();
        return v || null;
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

/**
 * Bearer token for ingest: password from `git credential fill` for GitLab host.
 */
function resolveAuthTokenFromGitCredential() {
  return readGitCredential(GITLAB_CREDENTIAL_HOST);
}

// ---------------------------------------------------------------------------
// Idempotency key (AC#9 — must match server/src/live/idempotency.ts exactly)
// ---------------------------------------------------------------------------

/**
 * sha256([actor, event_type, skill_name ?? '', occurred_at.toISOString().slice(0,19)].join('|'))
 * Returns hex string.
 */
function deriveIdempotencyKey(actor, eventType, skillName, occurredAt) {
  const parts = [
    actor,
    eventType,
    skillName != null ? skillName : '',
    occurredAt.toISOString().slice(0, 19),
  ].join('|');
  return crypto.createHash('sha256').update(parts).digest('hex');
}

// ---------------------------------------------------------------------------
// Payload assembly (AC#8)
// ---------------------------------------------------------------------------

/**
 * Build commit_message_draft trailer, truncated to ≤80 chars.
 * Format: "AI-Phase: <phase>\nAI-Tool: <tool>\nStory-Ref: <ref>"
 */
function buildCommitMessageDraft(aiPhase, aiTool, storyRef) {
  const lines = [`AI-Phase: ${aiPhase}`, `AI-Tool: ${aiTool}`];
  if (storyRef) lines.push(`Story-Ref: ${storyRef}`);
  const full = lines.join('\n');
  // Truncate to 80 chars on the joined string
  return full.slice(0, 80);
}

// ---------------------------------------------------------------------------
// HTTP POST helper (no axios, no fetch — just http/https built-ins)
// ---------------------------------------------------------------------------

function postJSON(url, payload, token) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const parsed = new URL(url);
    const mod = parsed.protocol === 'https:' ? https : http;

    const req = mod.request(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
        path: parsed.pathname + (parsed.search || ''),
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
          Authorization: `Bearer ${token}`,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => resolve({ status: res.statusCode, body: data }));
      }
    );

    req.on('error', reject);
    req.setTimeout(1800, () => {
      req.destroy(new Error('request timeout'));
    });
    req.write(body);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// Local queue helpers (story 8.4)
// ---------------------------------------------------------------------------

/**
 * Append a payload as one JSON line to the queue file.
 * Creates the file if absent (ENOENT handled gracefully — AC#6).
 */
function queueAppend(payload) {
  try {
    fs.appendFileSync(QUEUE_FILE, JSON.stringify(payload) + '\n', 'utf8');
  } catch (err) {
    process.stderr.write(
      `[aieye-live-hook] WARN: could not write to queue — ${err.message}\n`
    );
  }
}

/**
 * Read up to QUEUE_FLUSH_LIMIT lines from the queue file oldest-first.
 * Returns an array of parsed payload objects.
 * Returns [] if file is missing or unreadable.
 */
function queueRead() {
  let raw;
  try {
    raw = fs.readFileSync(QUEUE_FILE, 'utf8');
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    process.stderr.write(
      `[aieye-live-hook] WARN: could not read queue — ${err.message}\n`
    );
    return [];
  }

  const lines = raw.split('\n').filter((l) => l.trim().length > 0);
  const batch = lines.slice(0, QUEUE_FLUSH_LIMIT);
  const survivors = lines.slice(QUEUE_FLUSH_LIMIT); // lines beyond the batch stay

  const payloads = [];
  const unparseable = [];
  for (const line of batch) {
    try {
      payloads.push({ payload: JSON.parse(line), raw: line });
    } catch (_) {
      // Drop malformed lines — can't deliver them anyway
      unparseable.push(line);
    }
  }

  if (unparseable.length > 0) {
    process.stderr.write(
      `[aieye-live-hook] WARN: dropped ${unparseable.length} malformed queue line(s)\n`
    );
  }

  // Store surplus lines so queueRewrite can prepend them back
  queueRead._surplus = survivors;

  return payloads;
}
queueRead._surplus = [];

/**
 * Atomically rewrite the queue file.
 * failedLines: raw JSON strings for entries that could not be delivered.
 * Surplus lines (beyond the flush batch) are appended after failed lines.
 * Uses rename-to-replace for POSIX atomicity (AC#4).
 */
function queueRewrite(failedLines) {
  const allLines = [...failedLines, ...queueRead._surplus];
  if (allLines.length === 0) {
    // Queue fully drained — remove the file if it exists
    try { fs.unlinkSync(QUEUE_FILE); } catch (_) {}
    return;
  }
  const content = allLines.join('\n') + '\n';
  try {
    fs.writeFileSync(QUEUE_FILE_TMP, content, 'utf8');
    // POSIX rename(2) is atomic: readers always see either old or new file,
    // never a partial write. Concurrent processes may each rename; the last
    // writer wins. Server idempotency keys handle any resulting double-delivery.
    fs.renameSync(QUEUE_FILE_TMP, QUEUE_FILE);
  } catch (err) {
    process.stderr.write(
      `[aieye-live-hook] WARN: queue rewrite failed — ${err.message}\n`
    );
  }
}

/**
 * Flush queued events to the ingest endpoint.
 * Posts each in order; stops on first failure and rewrites survivors back.
 * Returns when done (either all sent or first failure).
 */
async function flushQueue(ingestUrl, token) {
  const entries = queueRead();
  if (entries.length === 0) return;

  const failed = []; // raw lines for entries we couldn't deliver

  for (const entry of entries) {
    let result;
    try {
      result = await postJSON(ingestUrl, entry.payload, token);
    } catch (_) {
      // Network error — stop flushing, preserve this and remaining entries
      failed.push(entry.raw);
      // Push the rest of the batch (not yet attempted) back as failed too
      const idx = entries.indexOf(entry);
      for (let i = idx + 1; i < entries.length; i++) {
        failed.push(entries[i].raw);
      }
      break;
    }

    if (result.status === 401) {
      // Token revoked — drop this entry, continue trying others
      process.stderr.write(
        `[aieye-live-hook] ERROR: 401 Unauthorized flushing queued event — event dropped.\n`
      );
      continue;
    }

    if (result.status < 200 || result.status >= 300) {
      // 5xx or other non-2xx — stop, preserve remaining entries
      failed.push(entry.raw);
      const idx = entries.indexOf(entry);
      for (let i = idx + 1; i < entries.length; i++) {
        failed.push(entries[i].raw);
      }
      break;
    }
    // 2xx — entry delivered, do not add to failed
  }

  queueRewrite(failed);
}

// ---------------------------------------------------------------------------
// Hook stdin parsing
// ---------------------------------------------------------------------------

/**
 * Claude Code passes JSON on stdin describing the tool invocation.
 * We read it all, then parse. Returns empty object on error.
 */
async function readStdin() {
  return new Promise((resolve) => {
    if (process.stdin.isTTY) {
      resolve({});
      return;
    }
    let buf = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { buf += chunk; });
    process.stdin.on('end', () => {
      try {
        resolve(JSON.parse(buf));
      } catch (_) {
        resolve({});
      }
    });
    process.stdin.on('error', () => resolve({}));
    // Safety timeout — stdin should close well inside the 2s ceiling
    setTimeout(() => resolve({}), 1500);
  });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  // 1. Load config
  const config = parseEnvFile(ENV_FILE);
  if (config === null) {
    // File missing — skip silently
    return;
  }

  // Stealth mode: user opted out of event publishing for this machine
  if (config['AIEYE_LIVE_STEALTH_MODE'] === 'true') return;

  const ingestUrl = INGEST_URL;
  const token = resolveAuthTokenFromGitCredential();
  const actor = config['AIEYE_LIVE_ACTOR'];
  const team = config['AIEYE_LIVE_TEAM'] || '';
  const allowedSkillsRaw = config['AIEYE_LIVE_SKILLS'] || '';

  if (!token || !actor) {
    // Not configured — skip silently
    return;
  }

  // 2. Parse hook stdin
  const hookData = await readStdin();

  // Extract skill_name from hook payload.
  // Claude Code PostToolUse passes something like { tool_name, tool_input, tool_response }
  // The skill name may live at hookData.tool_name or hookData.tool_input?.skill or argv[0].
  let skillName =
    hookData.tool_name ||
    (hookData.tool_input && hookData.tool_input.skill) ||
    process.argv[2] ||
    null;

  if (typeof skillName !== 'string') skillName = null;
  if (skillName) skillName = skillName.trim();

  // 3. Filter against AIEYE_LIVE_SKILLS (AC#6)
  const allowedSkills = allowedSkillsRaw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (allowedSkills.length > 0 && skillName && !allowedSkills.includes(skillName)) {
    // Not in allowed list — skip silently
    return;
  }

  // 4. Map skill → event_type (AC#7). Unknown skill → skip silently.
  const eventType = SKILL_EVENT_MAP[skillName];
  if (!eventType) {
    return;
  }

  // 5. Assemble payload (AC#8, AC#9)
  const occurredAt = new Date();
  // Truncate to second precision to match server key derivation
  const occurredAtTruncated = new Date(Math.floor(occurredAt.getTime() / 1000) * 1000);

  const storyRef = (hookData.tool_input && hookData.tool_input.story_ref) || null;
  const aiTool = config['AIEYE_LIVE_AI_TOOL'] || 'cli/claude';
  const aiPhase = 'code';

  const idempotencyKey = deriveIdempotencyKey(actor, eventType, skillName, occurredAtTruncated);

  const commitMessageDraft = buildCommitMessageDraft(aiPhase, aiTool, storyRef);

  const payload = {
    actor,
    event_type: eventType,
    occurred_at: occurredAtTruncated.toISOString(),
    skill_name: skillName,
    story_ref: storyRef || null,
    idempotency_key: idempotencyKey,
    metadata: {
      team: team || undefined,
      commit_message_draft: commitMessageDraft,
      ai_phase: aiPhase,
      ai_tool: aiTool,
    },
  };

  // 6. Flush any queued events from previous failures (AC#3–5)
  await flushQueue(ingestUrl, token);

  // 7. POST current event to ingest endpoint
  try {
    const result = await postJSON(ingestUrl, payload, token);

    if (result.status === 401) {
      // Token revoked — drop, do not queue (AC#2)
      process.stderr.write(
        `[aieye-live-hook] ERROR: 401 Unauthorized — token may be revoked. Event dropped.\n`
      );
      return;
    }

    if (result.status >= 500) {
      // 5xx server error — queue for retry (AC#1)
      process.stderr.write(
        `[aieye-live-hook] WARN: server returned ${result.status}. Event queued for retry.\n`
      );
      queueAppend(payload);
      return;
    }

    if (result.status < 200 || result.status >= 300) {
      process.stderr.write(
        `[aieye-live-hook] WARN: server returned ${result.status}. Event not confirmed.\n`
      );
    }
  } catch (err) {
    // Network error or timeout — queue for retry (AC#1)
    process.stderr.write(
      `[aieye-live-hook] WARN: POST failed — ${err.message}. Event queued for retry.\n`
    );
    queueAppend(payload);
  }
}

main().catch(() => {
  // All errors swallowed — skill must never be affected
  process.exit(0);
});
