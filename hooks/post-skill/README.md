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
# or from repo / npm global install:
node ./hooks/post-skill/lib/dispatch.js --check-deps
```

Exit **0** when Node and git are usable; otherwise messages go to stderr with hints.

## Installation

```bash
npm install -g /path/to/live-hook
# or from the workspace root:
npm install -g ./live-hook
```

After install, `aieye-live-hook` is on your PATH.

## Configuration

Create `~/.claude/aieye-live.env` with mode 600:

```bash
touch ~/.claude/aieye-live.env
chmod 600 ~/.claude/aieye-live.env
```

Events are always POSTed to **`https://doha-aieye.elasticrun.in/api/events`** (not configurable).

Add your settings:

```
AIEYE_LIVE_ACTOR=Your Name
AIEYE_LIVE_TEAM=alpha
AIEYE_LIVE_SKILLS=bmad-create-story,bmad-dev-story,bmad-code-review,bmad-qa-generate-e2e-tests
AIEYE_LIVE_AI_TOOL=cli/claude-sonnet-4-6
```

| Variable | Required | Description |
|---|---|---|
| `AIEYE_LIVE_ACTOR` | yes | Your display name shown on the TV |
| `AIEYE_LIVE_TEAM` | no | Team identifier |
| `AIEYE_LIVE_SKILLS` | no | Comma-separated skill names to emit events for. Leave empty to match all mapped skills. |
| `AIEYE_LIVE_STEALTH_MODE` | no | Set `true` to skip posting (no events). |

The bearer token is **only** the password returned by **`git credential fill`** for `https://engg.elasticrun.in/`. Configure credentials for that host via your credential helper / keychain / `.netrc` so `git credential` can supply the PAT.

> The token is sent as `Authorization: Bearer ...` to the ingest URL above. The hook never logs the raw token.

## Workflows and optional editor hooks

**Default:** each BMAD skill `workflow.md` ends with an **AIEye Live** step that runs the hook from the **global Claude install** with the workflow’s skill name. `scripts/install.sh` copies `hooks/post-skill/` to `~/.claude/hooks/aieye-live/`. Example:

```bash
AIEYE_HOOK="$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && "$AIEYE_HOOK" bmad-create-prd || true
```

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
