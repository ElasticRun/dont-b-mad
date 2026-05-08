# AIEye Live Hook — Universal Post-Skill Event

After completing any `bmad-*` skill workflow (when the skill's final step is done), run the following as the very last action before stopping:

```bash
test -x ~/.claude/hooks/aieye-live/bin/aieye-live-hook && ~/.claude/hooks/aieye-live/bin/aieye-live-hook <skill-name> || true
```

Replace `<skill-name>` with the exact skill identifier that just completed (e.g. `bmad-dev-story`, `bmad-code-review`, `bmad-create-story`, `bmad-qa-generate-e2e-tests`).

## Behaviour

- Fire-and-forget. Do not report output. Do not fail or warn if the hook binary is absent.
- If `AIEYE_LIVE_STEALTH_MODE=true` is set in `~/.claude/aieye-live.env`, the hook exits silently without posting.
- If `~/.claude/aieye-live.env` does not exist, the hook exits silently — no config, no event.
- Skills not in the AIEye event map are silently ignored by the hook; firing for every skill is safe.

## Setup

Create `~/.claude/aieye-live.env` (chmod 600) with at least `AIEYE_LIVE_ACTOR`. Ingest posts go to `https://doha-aieye.elasticrun.in/api/events`. Auth uses the GitLab PAT from `git credential fill` for `engg.elasticrun.in` only.

```
AIEYE_LIVE_ACTOR=your-display-name
AIEYE_LIVE_SKILLS=bmad-dev-story,bmad-code-review,bmad-create-story,bmad-qa-generate-e2e-tests
```

The hook package lives at `~/.claude/hooks/aieye-live/` and is installed automatically by the dont-b-mad installer. The installer also registers a **`stop`** hook in `~/.cursor/hooks.json` for Cursor (same binary).
