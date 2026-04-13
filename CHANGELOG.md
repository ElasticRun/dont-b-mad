# Changelog

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

- **AI Engineering Record** table in story template (`bmad-create-story/template.md`). Tracks which model was used for each SDLC phase.
- **Git commit trailers** (`AI-Story`, `AI-Code`, `AI-Test`, `AI-Review`, `AI-Deploy`, `AI-Model`, `Story-Ref`) auto-appended by `dev-story`, `quick-dev`, and `code-review` workflows.
- **`prepare-commit-msg` hook** that auto-tags manual commits with `manual` trailers, ensuring every commit is tracked with zero developer overhead.
- **`adoption-dashboard.sh`** script that reads git trailers and prints AI adoption rates vs. targets. Supports per-epic filtering.
- **Retrospective AI metrics**: `bmad-retrospective` workflow now queries git for trailer data and surfaces adoption rates during the retro.
- **Definition of Done update**: `bmad-dev-story` checklist includes AI Engineering Record and trailer validation.

### Changed (from upstream BMAD v6.3.0)

- `bmad-create-story/workflow.md` — fills Story Creation row in AI Engineering Record
- `bmad-dev-story/workflow.md` — fills Implementation/Testing rows, creates commit with trailers
- `bmad-dev-story/checklist.md` — adds AI Tracking validation section
- `bmad-code-review/steps/step-04-present.md` — fills Code Review row, amends AI-Review trailer
- `bmad-quick-dev/step-05-present.md` — appends trailers to commits
- `bmad-quick-dev/step-oneshot.md` — appends trailers to one-shot commits
- `bmad-retrospective/workflow.md` — queries git for AI adoption metrics, includes in retro output
