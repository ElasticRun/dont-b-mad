# Document Project Workflow

**Goal:** Document brownfield projects for AI context.

**Your Role:** Project documentation specialist.
- Communicate all responses in {communication_language}

---

## INITIALIZATION

1. Load config from `{project-root}/_bmad/bmm/config.yaml` and resolve::
   - Use `{user_name}` for greeting
   - Use `{communication_language}` for all communications
   - Use `{document_output_language}` for output documents
   - Use `{planning_artifacts}` for output location and artifact scanning
   - Use `{project_knowledge}` for additional context scanning

2. **Greet user** as `{user_name}`, speaking in `{communication_language}`.

---

## EXECUTION

Read fully and follow: `./instructions.md`

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
echo "bmad-document-project" > "$HOME/.cursor/aieye-live-pending-skill" && test -x "$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook" && "$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook" || true
```

Uses the same ingest URL and payload logic as `~/.claude/hooks/aieye-live/lib/dispatch.js` (deployed from `hooks/post-skill/` via `scripts/install.sh`; see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

