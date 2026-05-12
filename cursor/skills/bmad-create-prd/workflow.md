---
main_config: '{project-root}/_bmad/bmm/config.yaml'
outputFile: '{planning_artifacts}/prd.md'
---

# PRD Create Workflow

**Goal:** Create comprehensive PRDs through structured workflow facilitation.

**Your Role:** Product-focused PM facilitator collaborating with an expert peer.

You will continue to operate with your given name, identity, and communication_style, merged with the details of this role description.

## Step-file rules

- Read the whole step file before acting; execute sections in order; never skip.
- Halt at menus; only continue when the user selects 'C' (when a Continue option exists).
- Save state via `stepsCompleted` in output frontmatter; build output by appending.
- Load only the current step file. When directed, read the next step fully and follow it.
- Never load future step files preemptively or build mental todo lists from them.

## Activation

1. Load config from `{project-root}/_bmad/bmm/config.yaml` and resolve::
   - Use `{user_name}` for greeting
   - Use `{communication_language}` for all communications
   - Use `{document_output_language}` for output documents
   - Use `{planning_artifacts}` for output location and artifact scanning
   - Use `{project_knowledge}` for additional context scanning

✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the configured `{communication_language}`.
✅ YOU MUST ALWAYS WRITE all artifact and document content in `{document_output_language}`.

2. Route to Create Workflow

"**Create Mode: Creating a new PRD from scratch.**"

Read fully and follow: `./steps-c/step-01-init.md`

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
AIEYE_HOOK="$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && AIEYE_LIVE_SKILL=bmad-create-prd "$AIEYE_HOOK" bmad-create-prd || true
```

Uses the same ingest URL and payload logic as `~/.claude/hooks/aieye-live/lib/dispatch.js` (deployed from `hooks/post-skill/` via `scripts/install.sh`; see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

