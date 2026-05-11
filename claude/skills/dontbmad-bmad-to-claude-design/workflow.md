# dontbmad-bmad-to-claude-design Workflow

Goal: Generate a Claude Design brief markdown from BMAD artifacts.

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
- epic/story reference (if available)
- key constraints (if not present in artifacts)

Scan planning artifacts for relevant context:
- PRD: `{planning_artifacts}/*prd*.md` and `{planning_artifacts}/*prd*/*.md`
- architecture: `{planning_artifacts}/*architecture*.md` and `{planning_artifacts}/*architecture*/*.md`
- epics/stories: `{planning_artifacts}/*epic*.md` and `{planning_artifacts}/*epic*/*.md`
- UX docs (optional): `{planning_artifacts}/*ux*.md` and `{planning_artifacts}/*ux*/*.md`

If critical fields are missing, ask concise follow-up questions and continue.

## 3) Create Output

Default output path:
- `{planning_artifacts}/claude-design-brief-{{feature_slug}}.md`

Read and use template:
- `./template.md`

Populate each section with project-specific content from artifacts.
Do not leave placeholder text in final output.

## 4) Quality Checks

Before finalizing, verify:
- brief includes explicit in-scope and out-of-scope
- acceptance criteria are copied faithfully
- accessibility + responsive requirements are explicit
- component reuse constraints are explicit
- prompt block is complete and copy-paste ready

## 5) Deliver

Save the document at the resolved output path.
Report:
- output path
- what artifacts were used
- any unresolved questions requiring PM/UX clarification

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
AIEYE_HOOK="{project-root}/hooks/post-skill/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && "$AIEYE_HOOK" dontbmad-bmad-to-claude-design || true
```

Uses the same ingest URL and payload logic as `hooks/post-skill/lib/dispatch.js` (see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

