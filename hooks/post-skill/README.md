# @aieye/live-hook

BMAD post-skill hook that fires celebration events to the AIEye Live ingest endpoint. Fire-and-forget: the foreground exits in under 50ms regardless of network conditions.

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

Events are always POSTed to **`https://doha-aieye.elasticrun.in/api/ingest`** (not configurable).

Add your settings:

```
AIEYE_LIVE_ACTOR=Your Name
AIEYE_LIVE_TEAM=alpha
AIEYE_LIVE_SKILLS=bmad-create-story,bmad-dev-story,bmad-code-review,bmad-qa-generate-e2e-tests
AIEYE_LIVE_AI_TOOL=cli/claude-sonnet-4-6
# Optional — GitLab host passed to `git credential fill` (default: gitlab.com)
# AIEYE_LIVE_GITLAB_HOST=gitlab.example.com
```

| Variable | Required | Description |
|---|---|---|
| `AIEYE_LIVE_ACTOR` | yes | Your display name shown on the TV |
| `AIEYE_LIVE_GITLAB_HOST` | no | GitLab host for `git credential fill` (default `gitlab.com`). |
| `AIEYE_LIVE_TEAM` | no | Team identifier |
| `AIEYE_LIVE_SKILLS` | no | Comma-separated skill names to emit events for. Leave empty to match all mapped skills. |
| `AIEYE_LIVE_STEALTH_MODE` | no | Set `true` to skip posting (no events). |

The bearer token is **only** the password returned by **`git credential fill`** for `https://<host>/`, where `<host>` is `AIEYE_LIVE_GITLAB_HOST` or `gitlab.com`. Configure GitLab credentials via your usual credential helper / keychain / `.netrc` so `git credential` can supply the PAT.

> The token is sent as `Authorization: Bearer ...` to the ingest URL above. The hook never logs the raw token.

## Register in Claude Code

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "SkillTool",
        "hooks": [
          { "type": "command", "command": "aieye-live-hook" }
        ]
      }
    ]
  }
}
```

## Supported skills

| BMAD skill | Event type |
|---|---|
| `bmad-create-story` | `story_created` |
| `bmad-dev-story` | `story_developed` |
| `bmad-code-review` | `review_landed` |
| `bmad-qa-generate-e2e-tests` | `test_added` |

Unknown skills are silently skipped — the hook never fails.

## Safety guarantees

- Foreground exit under 50ms (background subshell + `timeout 2`).
- `|| true` ensures even a crashed or timed-out dispatcher never marks a skill failed.
- Uses `git credential fill` only (no `git` repo required for the hook process).
- No npm dependencies — runs on Node 18+ with zero install inside `live-hook/`.

## Running tests

```bash
cd live-hook
node --test lib/*.test.js
```
