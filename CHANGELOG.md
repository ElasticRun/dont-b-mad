# Changelog

## 2.1.0 (2026-04-30)

### Added

- `dontbmad-grill` -- new skill: relentless one-question-at-a-time decision-tree interrogation with a recommended answer for every node. Reads existing artifacts, project-context, and codebase before asking. Returns a structured `Grilled Decisions` table the calling skill can append to the artifact. Adapted from [grill-me](https://github.com/mattpocock/skills/tree/main/skills/productivity/grill-me) by Matt Pocock (MIT).
- `bmad-create-architecture` (step-04-decisions) -- A/P/C menu extended to A/P/G/C. New `G` option invokes `dontbmad-grill` with the current decision category as `topic` and the recorded decisions as `draft_so_far`. Returned table is merged into the category's content; deferred rows go into the document's deferred decisions section.
- `bmad-create-story` (step 5b) -- new step between story creation and finalization. Steps 2-4 now collect ambiguities into an `{{open_questions}}` list as they analyze artifacts. If the list is empty the story stays fully automated and step 5b is skipped; if non-empty, `dontbmad-grill` is auto-invoked at `light` intensity with the open questions as decision-tree roots. Resolved decisions are merged inline into the story (acceptance criteria, dev notes, technical context); unresolved items become an `## Open Questions` section the dev agent reads first. Closes the previously-broken "save questions for the end" promise that had no execution step.

### Changed

- `dontbmad-grill` default intensity now depends on invocation path: `standard` for direct user invocation, `light` for auto-invocation by another skill. Calling skills can prompt the user to escalate to `standard` or `relentless` after the light pass returns.
- Question template now includes a `Q{n} of ~{budget}` line so the user can pace themselves. Budget recomputes if the decision tree changes mid-grill (loop detection).

## 2.0.0 (2026-04-13)

Simplified trailer scheme. Every commit now gets exactly three trailers (`AI-Phase`, `AI-Tool`, `Story-Ref`) instead of 5-7. One commit = one phase.

### Breaking Changes

- Old trailers (`AI-Story`, `AI-Code`, `AI-Test`, `AI-Review`, `AI-Deploy`, `AI-Model`, `AI-Artifact`, `AI-Author`) are replaced by `AI-Phase` + `AI-Tool`.
- Dashboard no longer recognizes old trailer format. Re-run workflows to generate new-format commits, or manually add trailers to existing commits.

### Changed

- All planning workflows (`create-prd`, `create-epics-and-stories`, `create-architecture`, `create-ux-design`, `sprint-planning`, `create-story`) now commit with `AI-Phase: {type}`, `AI-Tool: {model}`, `Story-Ref: {ref}`.
- All development workflows (`dev-story`, `quick-dev`, `code-review`) now commit with the same three trailers.
- `prepare-commit-msg` hook detects `AI-Phase:` instead of `AI-Code:` or `AI-Artifact:`. Tags manual commits with `AI-Phase: code`, `AI-Tool: manual`.
- `adoption-dashboard.sh` (Pulse) groups commits by `AI-Phase` value and shows per-phase adoption rates.
- Story template AI Engineering Record table uses `AI-Phase | AI-Tool | Story-Ref` columns.
- Retrospective workflow queries the new trailer format and reports adoption by phase.

## 1.1.0 (2026-04-13)

Added git checkpoints with AI trailers to all planning workflows.

### Added

- `bmad-create-prd` (step-12-complete) -- auto-commits PRD with AI trailers on completion
- `bmad-create-epics-and-stories` (step-04-final-validation) -- auto-commits epics with AI trailers on completion
- `bmad-create-architecture` (step-08-complete) -- auto-commits architecture doc with AI trailers on completion
- `bmad-create-ux-design` (step-14-complete) -- auto-commits UX design with AI trailers on completion
- `bmad-sprint-planning` (workflow step 5) -- auto-commits sprint status with AI trailers on completion
- `bmad-create-story` (workflow step 6) -- auto-commits story file with AI trailers on creation

## 1.0.0 (2026-04-12)

Initial release. Fork of BMAD v6.3.0 with AI tracking extensions.

### Added

- **AI Engineering Record** table in story template (`bmad-create-story/template.md`).
- **Git commit trailers** auto-appended by `dev-story`, `quick-dev`, and `code-review` workflows.
- **`prepare-commit-msg` hook** that auto-tags manual commits.
- **`adoption-dashboard.sh`** script that reads git trailers and prints AI adoption rates vs. targets.
- **Retrospective AI metrics**: `bmad-retrospective` workflow queries git for trailer data during the retro.
- **Definition of Done update**: `bmad-dev-story` checklist includes AI tracking validation.
