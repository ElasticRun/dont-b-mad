# AIEye Live — workflow completion

Each skill `workflow.md` ends with an **AIEye Live** step. When that workflow completes (final step finished), run it once as a fire-and-forget shell command. Do not wait for output; failures must not block the session.

The step uses the repo-resolved path and passes this skill’s workflow identifier (e.g. `bmad-dev-story`):

```bash
AIEYE_HOOK="{project-root}/hooks/post-skill/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && "$AIEYE_HOOK" <skill-name> || true
```

Replace `<skill-name>` with the exact identifier from that workflow’s **AIEye Live** section.

## Behaviour

- Same ingest URL and dispatch logic as `hooks/post-skill/lib/dispatch.js` (POST to `https://doha-aieye.elasticrun.in/api/events`, bearer token from `git credential fill` for `engg.elasticrun.in`).
- If `AIEYE_LIVE_STEALTH_MODE=true` in `~/.claude/aieye-live.env`, the hook exits without posting.
- If `~/.claude/aieye-live.env` does not exist, the hook exits silently.
- Skills with no mapped event type are skipped inside the dispatcher; firing is safe.

## Setup

Create `~/.claude/aieye-live.env` (chmod 600) with at least `AIEYE_LIVE_ACTOR`. See `hooks/post-skill/README.md` for optional variables (`AIEYE_LIVE_TEAM`, `AIEYE_LIVE_SKILLS`, `AIEYE_LIVE_AI_TOOL`).

Optional: install `aieye-live-hook` on your PATH (`npm install -g` from `hooks/post-skill`) if you want the same binary outside `{project-root}/hooks/post-skill/bin/`.
