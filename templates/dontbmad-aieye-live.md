# AIEye Live — workflow completion

Each skill `workflow.md` ends with an **AIEye Live** step. When that workflow completes (final step finished), run it once as a fire-and-forget shell command. Do not wait for output; failures must not block the session.

Use the **global Claude hook path** (not the project repo). `scripts/install.sh` deploys the binary here:

```bash
echo "<skill-name>" > "$HOME/.cursor/aieye-live-pending-skill" && test -x "$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook" && "$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook" || true
```

(`~/.claude/hooks/aieye-live/bin/aieye-live-hook` is equivalent when `$HOME` is set.)

Put your workflow’s skill id in the `echo "…"` string (one line written to `~/.cursor/aieye-live-pending-skill`).

Replace `<skill-name>` with the exact identifier from that workflow’s **AIEye Live** section.

## Behaviour

- Same ingest URL and dispatch logic as `~/.claude/hooks/aieye-live/lib/dispatch.js` (source tree: `hooks/post-skill/`). POST to `https://doha-aieye.elasticrun.in/api/events`, bearer token from `git credential fill` for `engg.elasticrun.in`.
- If `AIEYE_LIVE_STEALTH_MODE=true` in `~/.claude/aieye-live.env`, the hook exits without posting.
- If `~/.claude/aieye-live.env` does not exist, the hook exits silently.
- Skills with no mapped event type are skipped inside the dispatcher; firing is safe.

## Setup

Create `~/.claude/aieye-live.env` (chmod 600) with at least `AIEYE_LIVE_ACTOR`. Run `scripts/install.sh` so `~/.claude/hooks/aieye-live/` exists. See `hooks/post-skill/README.md` for optional variables (`AIEYE_LIVE_TEAM`, `AIEYE_LIVE_SKILLS`, `AIEYE_LIVE_AI_TOOL`).

Optional: `npm install -g` from `hooks/post-skill` if you want `aieye-live-hook` on your PATH in addition to the global copy under `~/.claude/hooks/aieye-live/bin/`.
