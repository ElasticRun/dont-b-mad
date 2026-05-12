# @aieye/live-hook

BMAD post-skill hook that fires celebration events to the AIEye Live ingest endpoint. Fire-and-forget: the foreground exits in under 50ms regardless of network conditions.

## System dependencies

The hook does **not** use external GNU **`timeout`**; the ~2 s ceiling is enforced inside Node so stock macOS works.

| Requirement | Why |
|---|---|
| **bash** | Wrapper script (`/usr/bin/env bash`). |
| **Node.js ≥ 18** | Runs `lib/dispatch.js`. |
| **git** on `PATH** | Bearer token via `git credential fill` for the GitLab host. |

Verify on the target machine (after `scripts/install.sh`, or from a checkout):

```bash
~/.claude/hooks/aieye-live/bin/aieye-live-hook --check-deps
# or:
node ./hooks/post-skill/lib/dispatch.js --check-deps
```

Workflows write the skill id to **`~/.cursor/aieye-live-pending-skill`** (one line) in the same shell command as the hook, because some agents spawn `node …/dispatch.js` without env or argv; `dispatch.js` reads and deletes that file when resolving `skill_name`.

```bash
echo "bmad-create-prd" > "$HOME/.cursor/aieye-live-pending-skill" && test -x "$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook" && "$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook" || true
```

The bash wrapper logs a **`BASH:`** line to `~/.cursor/aieye-live-hook.log` on each run (argc, argv, env lengths, pending file presence). It also **exports `AIEYE_LIVE_SKILL` from the first positional argument** when env was unset, so `node` still inherits the skill when the wrapper is invoked as `hook bmad-create-prd`.

**Optional — Claude Code / Cursor stop hooks:** merge a **Stop** / **stop** hook with helper scripts in this repo (binary path should be `~/.claude/hooks/aieye-live/bin/aieye-live-hook` after install):

- `scripts/register-post-skill-hook.py` — Claude `~/.claude/settings.json`
- `scripts/register-cursor-aieye-stop-hook.py` — Cursor `~/.cursor/hooks.json`

Point the `command` at your installed `aieye-live-hook` binary. Cursor watches `hooks.json`; restart Cursor after changes.

## Supported skills

| BMAD skill | Event type |
|---|---|
| `bmad-create-story` | `story_created` |
| `bmad-dev-story` | `story_developed` |
| `bmad-code-review` | `review_landed` |
| `bmad-qa-generate-e2e-tests` | `test_added` |

Unknown skills are silently skipped — the hook never fails.

## Safety guarantees

- Foreground exit under ~50 ms (`( … ) &`); dispatcher runs in the background with a ~2 s Node-enforced deadline.
- `|| true` ensures even a crashed or terminated dispatcher never marks the agent/skill failed.
- Uses `git credential fill` only (no `git` repo required for the hook process).
- No npm dependencies — runs on Node 18+ with zero install inside `live-hook/`.

## Running tests

```bash
cd live-hook
node --test lib/*.test.js
```
