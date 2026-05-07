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

Add your settings:

```
AIEYE_LIVE_INGEST_URL=https://aieye.internal/api/events
AIEYE_LIVE_ACTOR=Your Name
AIEYE_LIVE_TEAM=alpha
AIEYE_LIVE_SKILLS=bmad-create-story,bmad-dev-story,bmad-code-review,bmad-qa-generate-e2e-tests
AIEYE_LIVE_AI_TOOL=cli/claude-sonnet-4-6
# Optional — overrides the GitLab host used for credential lookup (default: gitlab.com)
# AIEYE_LIVE_GITLAB_HOST=gitlab.example.com
```

| Variable | Required | Description |
|---|---|---|
| `AIEYE_LIVE_INGEST_URL` | yes | Full URL to the celebration ingest endpoint |
| `AIEYE_LIVE_ACTOR` | yes | Your display name shown on the TV |
| `AIEYE_LIVE_TOKEN` | no | Direct ingest bearer token. Highest priority when set. |
| `AIEYE_LIVE_GITLAB_TOKEN` | no | Explicit GitLab PAT to bear (skips automatic lookup). |
| `AIEYE_LIVE_GITLAB_HOST` | no | GitLab host queried when looking up credentials (default `gitlab.com`). |
| `AIEYE_LIVE_TEAM` | no | Team identifier |
| `AIEYE_LIVE_SKILLS` | no | Comma-separated skill names to emit events for. Leave empty to match all mapped skills. |
| `AIEYE_LIVE_AI_TOOL` | no | AI tool identifier for the AI Engineering Record trailer (default: `cli/claude`) |

### Token resolution

The hook resolves the bearer token in this order — first hit wins:

1. `AIEYE_LIVE_TOKEN` (env file) — opaque ingest token
2. `AIEYE_LIVE_GITLAB_TOKEN` (env file) — explicit GitLab PAT
3. `GITLAB_TOKEN` / `GL_TOKEN` (process env)
4. `glab auth token -h <host>` (glab CLI)
5. `git credential fill` for `<host>` (system credential helpers / keychain / `.netrc`)
6. `~/.config/glab-cli/config.yml`

`<host>` defaults to `gitlab.com` and is overridden by `AIEYE_LIVE_GITLAB_HOST`.

This means a developer who already has `glab auth login` or a git credential helper set up for their GitLab instance gets ingest auth for free — no separate token to mint or distribute. If you do not want the hook to read your GitLab credentials, set `AIEYE_LIVE_TOKEN` explicitly to keep the existing behaviour.

> Whatever the hook resolves is sent verbatim as `Authorization: Bearer ...` to the ingest URL. Make sure that URL points only at servers you trust to handle a GitLab PAT — the hook itself never logs the raw token.

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
- No git operations. Works outside any repository.
- No npm dependencies — runs on Node 18+ with zero install inside `live-hook/`.

## Running tests

```bash
cd live-hook
node --test lib/*.test.js
```
