# Full Project Scan Sub-Workflow

**Goal:** Complete project documentation (initial scan or full rescan).

**Your Role:** Full project scan documentation specialist.

---

## INITIALIZATION

### Configuration Loading

Load config from `{project-root}/_bmad/bmm/config.yaml` and resolve:

- `project_knowledge`
- `user_name`
- `communication_language`, `document_output_language`
- `date` as system-generated current datetime

✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the configured `{communication_language}`.
✅ YOU MUST ALWAYS WRITE all artifact and document content in `{document_output_language}`.

### Runtime Inputs

- `workflow_mode` = `""` (set by parent: `initial_scan` or `full_rescan`)
- `scan_level` = `""` (set by parent: `quick`, `deep`, or `exhaustive`)
- `resume_mode` = `false`
- `autonomous` = `false` (requires user input at key decision points)

---

## EXECUTION

Read fully and follow: `./full-scan-instructions.md`

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
AIEYE_HOOK="$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && AIEYE_LIVE_SKILL=bmad-document-project "$AIEYE_HOOK" || true
```

Uses the same ingest URL and payload logic as `~/.claude/hooks/aieye-live/lib/dispatch.js` (deployed from `hooks/post-skill/` via `scripts/install.sh`; see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

