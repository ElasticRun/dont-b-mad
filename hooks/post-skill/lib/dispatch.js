'use strict';
/**
 * dispatch.js — AIEye Live hook dispatcher
 *
 * Reads ~/.claude/aieye-live.env for actor / filters; POSTs to a fixed ingest URL.
 * Bearer token always comes from `git credential fill` for the GitLab host.
 * No npm dependencies — only Node.js built-ins.
 *
 * Called by bin/aieye-live-hook in a background subshell. A ~2s wall-clock deadline is
 * enforced in this process (no external `timeout` command — portable on macOS/Linux).
 *
 * Debugging: set AIEYE_LIVE_DEBUG=1 (or true/yes). Logs execution path and errors
 * to stderr; the wrapper script preserves stderr when this variable is set.
 * All debug-style tracing is also appended (always) to ~/.cursor/aieye-live-hook.log
 * regardless of AIEYE_LIVE_DEBUG.
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
// Debug logging (stderr only; enable with AIEYE_LIVE_DEBUG=1|true|yes)
// ---------------------------------------------------------------------------

function isDebugEnabled() {
  const v = String(process.env.AIEYE_LIVE_DEBUG || '').trim().toLowerCase();
  return v === '1' || v === 'true' || v === 'yes';
}

/**
 * Append one timestamped line to ~/.cursor/aieye-live-hook.log.
 * Must never throw — failures here must not break the hook.
 * @param {string} message
 */
function persistHookLog(message) {
  try {
    fs.mkdirSync(path.dirname(HOOK_FILE_LOG), { recursive: true });
    const line = `[${new Date().toISOString()}] ${message}\n`;
    fs.appendFileSync(HOOK_FILE_LOG, line, 'utf8');
  } catch (_) {
    // ignore
  }
}

const DEBUG = isDebugEnabled();

/** @param {string} message */
function debugLog(message) {
  persistHookLog(`DEBUG: ${message}`);
  if (!DEBUG) return;
  process.stderr.write(`[aieye-live-hook] DEBUG: ${message}\n`);
}

/**
 * @param {string} context
 * @param {unknown} err
 */
function debugError(context, err) {
  const msg = err && typeof err === 'object' && 'message' in err && err.message != null
    ? String(err.message)
    : String(err);
  persistHookLog(`DEBUG ERROR [${context}]: ${msg}`);
  if (err && typeof err === 'object' && 'stack' in err && err.stack) {
    persistHookLog(String(err.stack));
  }
  if (!DEBUG) return;
  process.stderr.write(`[aieye-live-hook] DEBUG ERROR [${context}]: ${msg}\n`);
  if (err && typeof err === 'object' && 'stack' in err && err.stack) {
    process.stderr.write(String(err.stack) + '\n');
  }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const ENV_FILE = path.join(os.homedir(), '.claude', 'aieye-live.env');
/** Persistent hook trace log (always written; see persistHookLog). */
const HOOK_FILE_LOG = path.join(os.homedir(), '.cursor', 'aieye-live-hook.log');
const QUEUE_FILE = path.join(os.homedir(), '.claude', 'aieye-live-queue.jsonl');
const QUEUE_FILE_TMP = QUEUE_FILE + '.tmp';
const QUEUE_FLUSH_LIMIT = 100;

/** Fixed AIEye Live ingest endpoint (not configurable). */
const INGEST_URL = 'https://doha-aieye.elasticrun.in/api/events';

/** GitLab host for `git credential fill` only (not configurable). */
const GITLAB_CREDENTIAL_HOST = 'engg.elasticrun.in';

/** Skill name → event_type overrides (AC#7). Other bmad-* / dontbmad-* use derived types. */
const SKILL_EVENT_MAP = {
  'bmad-create-story': 'story_created',
  'bmad-dev-story': 'story_developed',
  'bmad-code-review': 'review_landed',
  'bmad-qa-generate-e2e-tests': 'test_added',
};

/** @param {string | null} skillName */
function resolveEventType(skillName) {
  if (!skillName) return null;
  const mapped = SKILL_EVENT_MAP[skillName];
  if (mapped) return mapped;
  if (skillName.startsWith('bmad-') || skillName.startsWith('dontbmad-')) {
    return `${skillName.replace(/-/g, '_')}_completed`;
  }
  return null;
}

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
      const warn =
        `[aieye-live-hook] WARNING: ${filePath} is world-readable (mode ${mode.toString(8)}). ` +
        'Set permissions to 600: chmod 600 ~/.claude/aieye-live.env\n';
      persistHookLog(
        `WARNING: ${filePath} is world-readable (mode ${mode.toString(8)}); chmod 600 aieye-live.env`
      );
      process.stderr.write(warn);
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

/** Wall-clock limit for the whole hook process (matches former shell `timeout 2`). */
const HOOK_MAX_RUNTIME_MS = 2000;

/** Print problems and exit 1. Used by --check-deps. */
function printDependencyProblems(problems) {
  persistHookLog('check-deps: failed');
  for (const p of problems) persistHookLog(`check-deps: ${p}`);
  process.stderr.write('[aieye-live-hook] Dependency check failed:\n');
  for (const p of problems) process.stderr.write(`  • ${p}\n`);
  process.stderr.write(
    '\nRequired: Node.js 18+ and git on PATH. Git supplies the ingest token via ' +
      '`git credential fill` for the configured GitLab host.\n' +
      'The wrapper script uses bash (#!/usr/bin/env bash).\n' +
      'Run: aieye-live-hook --check-deps  or  node /path/to/lib/dispatch.js --check-deps\n'
  );
}

/**
 * Offline verify runtime deps (node version + git). Exits process; never runs ingest.
 */
function runCheckDepsCli() {
  if (!process.argv.includes('--check-deps')) return;

  const problems = [];
  const major = Number(process.versions.node.split('.')[0]);
  if (!Number.isFinite(major) || major < 18) {
    problems.push(`Node.js >= 18 required (found ${process.version})`);
  }

  let res;
  try {
    res = spawnSync('git', ['--version'], {
      timeout: SUBPROCESS_TIMEOUT_MS,
      encoding: 'utf8',
    });
  } catch (e) {
    problems.push(`git not runnable: ${e.message}`);
    printDependencyProblems(problems);
    process.exit(1);
  }

  if (res.error) {
    problems.push(`git: ${res.error.message}`);
  } else if (res.status !== 0) {
    problems.push(`git --version exited with status ${res.status}`);
  } else if (!String(res.stdout || '').trim()) {
    problems.push('git --version produced no output');
  }

  if (problems.length > 0) {
    printDependencyProblems(problems);
    process.exit(1);
  }

  process.exit(0);
}

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
    persistHookLog(`WARN: could not write to queue — ${err.message}`);
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
    persistHookLog(`WARN: could not read queue — ${err.message}`);
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
    persistHookLog(`WARN: dropped ${unparseable.length} malformed queue line(s)`);
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
    persistHookLog(`WARN: queue rewrite failed — ${err.message}`);
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
  if (entries.length === 0) {
    debugLog('flushQueue: queue empty, nothing to flush');
    return;
  }

  debugLog(`flushQueue: processing ${entries.length} queued event(s)`);
  const failed = []; // raw lines for entries we couldn't deliver

  for (const entry of entries) {
    let result;
    try {
      result = await postJSON(ingestUrl, entry.payload, token);
    } catch (err) {
      debugError('flushQueue POST', err);
      // Network error — stop flushing, preserve this and remaining entries
      failed.push(entry.raw);
      // Push the rest of the batch (not yet attempted) back as failed too
      const idx = entries.indexOf(entry);
      for (let i = idx + 1; i < entries.length; i++) {
        failed.push(entries[i].raw);
      }
      debugLog(`flushQueue: stopped on network error; ${failed.length} line(s) kept in queue`);
      break;
    }

    if (result.status === 401) {
      // Token revoked — drop this entry, continue trying others
      persistHookLog('ERROR: 401 Unauthorized flushing queued event — event dropped.');
      process.stderr.write(
        `[aieye-live-hook] ERROR: 401 Unauthorized flushing queued event — event dropped.\n`
      );
      debugLog('flushQueue: 401 on queued item — dropped, continuing');
      continue;
    }

    if (result.status < 200 || result.status >= 300) {
      debugLog(`flushQueue: HTTP ${result.status} — stopping flush; remainder re-queued`);
      // 5xx or other non-2xx — stop, preserve remaining entries
      failed.push(entry.raw);
      const idx = entries.indexOf(entry);
      for (let i = idx + 1; i < entries.length; i++) {
        failed.push(entries[i].raw);
      }
      break;
    }
    debugLog(`flushQueue: delivered one queued event (HTTP ${result.status})`);
    // 2xx — entry delivered, do not add to failed
  }

  queueRewrite(failed);
  debugLog(`flushQueue: finished (failed backlog lines: ${failed.length})`);
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
      debugLog('stdin: isTTY=true, using empty hook payload');
      resolve({});
      return;
    }
    let buf = '';
    let settled = false;
    const finish = (label, value) => {
      if (settled) return;
      settled = true;
      debugLog(`stdin: ${label} (bytes=${buf.length})`);
      resolve(value);
    };

    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { buf += chunk; });
    process.stdin.on('end', () => {
      try {
        finish('parsed JSON', JSON.parse(buf));
      } catch (err) {
        debugError('stdin JSON parse', err);
        finish('invalid JSON, using {}', {});
      }
    });
    process.stdin.on('error', (err) => {
      debugError('stdin stream', err);
      finish('stream error, using {}', {});
    });
    // Safety timeout — stdin should close well inside the 2s ceiling
    setTimeout(() => {
      if (!settled) {
        debugLog('stdin: safety timeout (1500ms), using {}');
        finish('timeout', {});
      }
    }, 1500);
  });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  debugLog(`start argv=${JSON.stringify(process.argv.slice(2))}`);
  // 1. Load config
  const config = parseEnvFile(ENV_FILE);
  if (config === null) {
    debugLog(`exit: env file missing (${ENV_FILE}) — skipping`);
    // File missing — skip silently
    return;
  }

  // Stealth mode: user opted out of event publishing for this machine
  if (config['AIEYE_LIVE_STEALTH_MODE'] === 'true') {
    debugLog('exit: AIEYE_LIVE_STEALTH_MODE=true — skipping');
    return;
  }

  const ingestUrl = INGEST_URL;
  const token = resolveAuthTokenFromGitCredential();
  const actor = config['AIEYE_LIVE_ACTOR'];
  const team = config['AIEYE_LIVE_TEAM'] || '';
  const allowedSkillsRaw = config['AIEYE_LIVE_SKILLS'] || '';

  if (!token || !actor) {
    const missing = [!token && 'git credential token', !actor && 'AIEYE_LIVE_ACTOR']
      .filter(Boolean)
      .join(', ');
    debugLog(`exit: missing ${missing} — skipping`);
    // Not configured — skip silently
    return;
  }

  debugLog(`config: actor set, team=${team ? '(set)' : '(empty)'} ingest=${ingestUrl}`);

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

  debugLog(
    `resolved skill_name=${skillName === null ? '(null)' : JSON.stringify(skillName)}`
  );
  const allowedSkills = allowedSkillsRaw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (allowedSkills.length > 0 && skillName && !allowedSkills.includes(skillName)) {
    debugLog(`exit: skill "${skillName}" not in AIEYE_LIVE_SKILLS — skipping`);
    // Not in allowed list — skip silently
    return;
  }

  // 4. Map skill → event_type (AC#7). Unknown / non-BMAD skill → skip silently.
  const eventType = resolveEventType(skillName);
  if (!eventType) {
    debugLog(
      `exit: no event_type for skill=${skillName === null ? '(null)' : JSON.stringify(skillName)} — skipping`
    );
    return;
  }

  debugLog(`path: skill=${JSON.stringify(skillName)} → event_type=${eventType}`);

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
  debugLog('ingest: posting current event…');
  try {
    const result = await postJSON(ingestUrl, payload, token);
    debugLog(`ingest: response HTTP ${result.status}`);

    if (result.status === 401) {
      // Token revoked — drop, do not queue (AC#2)
      persistHookLog('ERROR: 401 Unauthorized — token may be revoked. Event dropped.');
      process.stderr.write(
        `[aieye-live-hook] ERROR: 401 Unauthorized — token may be revoked. Event dropped.\n`
      );
      debugLog('exit: 401 on current event — dropped');
      return;
    }

    if (result.status >= 500) {
      // 5xx server error — queue for retry (AC#1)
      persistHookLog(`WARN: server returned ${result.status}. Event queued for retry.`);
      process.stderr.write(
        `[aieye-live-hook] WARN: server returned ${result.status}. Event queued for retry.\n`
      );
      debugLog(`error path: ${result.status} server — event queued`);
      queueAppend(payload);
      return;
    }

    if (result.status < 200 || result.status >= 300) {
      persistHookLog(`WARN: server returned ${result.status}. Event not confirmed.`);
      process.stderr.write(
        `[aieye-live-hook] WARN: server returned ${result.status}. Event not confirmed.\n`
      );
      debugLog(`warn path: HTTP ${result.status} — event not confirmed (not queued)`);
      return;
    }

    debugLog(`done: event sent event_type=${eventType} skill=${JSON.stringify(skillName)}`);
  } catch (err) {
    debugError('ingest POST', err);
    // Network error or timeout — queue for retry (AC#1)
    persistHookLog(`WARN: POST failed — ${err.message}. Event queued for retry.`);
    process.stderr.write(
      `[aieye-live-hook] WARN: POST failed — ${err.message}. Event queued for retry.\n`
    );
    queueAppend(payload);
  }
}

runCheckDepsCli();

const hookHardKill = setTimeout(() => process.exit(0), HOOK_MAX_RUNTIME_MS);

main()
  .catch((err) => {
    const msg =
      err && typeof err === 'object' && err.message != null ? String(err.message) : String(err);
    persistHookLog(`ERROR: hook failed — ${msg}`);
    if (err && typeof err === 'object' && err.stack) {
      persistHookLog(String(err.stack));
    }
    process.stderr.write(`[aieye-live-hook] ERROR: hook failed — ${msg}\n`);
    if (DEBUG && err && typeof err === 'object' && err.stack) {
      process.stderr.write(String(err.stack) + '\n');
    }
  })
  .finally(() => {
    clearTimeout(hookHardKill);
    process.exit(0);
  });
