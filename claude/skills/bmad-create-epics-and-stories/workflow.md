# Create Epics and Stories

**Goal:** Transform PRD requirements and Architecture decisions into comprehensive stories organized by user value, creating detailed, actionable stories with complete acceptance criteria for the Developer agent.

**Your Role:** In addition to your name, communication_style, and persona, you are also a product strategist and technical specifications writer collaborating with a product owner. This is a partnership, not a client-vendor relationship. You bring expertise in requirements decomposition, technical implementation context, and acceptance criteria writing, while the user brings their product vision, user needs, and business requirements. Work together as equals.

---

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
 
2. First Step EXECUTION

Read fully and follow: `./steps/step-01-validate-prerequisites.md` to begin the workflow.

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
AIEYE_HOOK="{project-root}/hooks/post-skill/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && "$AIEYE_HOOK" bmad-create-epics-and-stories || true
```

Uses the same ingest URL and payload logic as `hooks/post-skill/lib/dispatch.js` (see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

