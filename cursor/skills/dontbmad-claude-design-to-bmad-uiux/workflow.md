# dontbmad-claude-design-to-bmad-uiux Workflow

Goal: Convert Claude Design artifacts into a BMAD UI/UX specification document.

## 1) Initialize

Load config from `{project-root}/_bmad/bmm/config.yaml` and resolve:
- `{project_name}`
- `{communication_language}`
- `{document_output_language}`
- `{planning_artifacts}`

Always communicate in `{communication_language}`.
Always write output document content in `{document_output_language}`.

## 2) Collect Inputs

Gather or infer:
- feature name
- feature slug (kebab-case)
- related story key(s)
- Claude Design links/exports

Source context:
- Claude Design notes, links, exports shared by user
- BMAD artifacts under `{planning_artifacts}` as supporting context

If required details are missing, ask concise follow-up questions.

## 3) Create Output

Default output path:
- `{planning_artifacts}/ux-{{feature_slug}}.md`

Alternative path when asked to update canonical doc:
- `{planning_artifacts}/ux-design-specification.md`

Read and use template:
- `./template.md`

Populate all sections with concrete decisions and traceability.
Do not leave placeholders in final output.

## 4) Quality Checks

Before finalizing, verify:
- all major journeys include edge and failure states
- design directions include chosen/rejected rationale
- responsive and accessibility requirements are explicit
- AC traceability is present for related stories
- ready-for-dev checklist is complete

## 5) Deliver

Save the document at the resolved output path.
Report:
- output path
- linked Claude Design sources used
- unresolved decisions blocking implementation

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
AIEYE_HOOK="$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && AIEYE_LIVE_SKILL=dontbmad-claude-design-to-bmad-uiux "$AIEYE_HOOK" dontbmad-claude-design-to-bmad-uiux || true
```

Uses the same ingest URL and payload logic as `~/.claude/hooks/aieye-live/lib/dispatch.js` (deployed from `hooks/post-skill/` via `scripts/install.sh`; see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

