# bmad-er

A fork of [BMAD v6.3.0](https://github.com/bmad-code-org) with AI tracking baked into every workflow. Measures AI adoption across the full SDLC without adding any overhead to developers.

Works with **Cursor** and **Claude Code**.

## What This Adds

Every git commit gets structured trailers recording AI involvement at each phase:

```
feat: implement wave planning task assignment

AI-Story: cursor/claude-sonnet-4-20250514
AI-Code: cursor/claude-sonnet-4-20250514
AI-Test: cursor/claude-sonnet-4-20250514
AI-Review: cursor/claude-sonnet-4-20250514
AI-Deploy: auto
AI-Model: claude-sonnet-4-20250514
Story-Ref: 1-1-wave-planning
```

Trailers are appended automatically. BMAD workflows (`create-story`, `dev-story`, `code-review`, `quick-dev`) fill them with the actual model used. A git hook catches manual commits and tags them with `manual`. Nobody types trailers by hand.

A dashboard script reads git history and prints adoption rates:

```
======================================
  AI Adoption Dashboard
======================================
  Total tracked commits: 8
--------------------------------------
  AI Story Rate:     75%  (target: 90%)
  AI Code Rate:      75%  (target: 80%)
  AI Test Rate:      50%  (target: 85%)
  AI Review Rate:    62%  (target: 95%)
  AI Deploy Rate:    71%  (target: 80%)
  Full Pipeline:     37%  (target: 70%)
======================================
```

## Install

```bash
git clone https://github.com/ElasticRun/bmad-er.git
bash bmad-er/scripts/install.sh /path/to/your/project
```

This copies skills into `.cursor/skills/` and `.claude/skills/`, installs the `prepare-commit-msg` hook, and drops the dashboard script into `scripts/`.

If you already have a `prepare-commit-msg` hook, the installer backs it up to `.bak` before replacing.

## What Gets Installed

| Location | What |
|---|---|
| `.cursor/skills/bmad-*` | All BMAD skills (Cursor) |
| `.claude/skills/bmad-*` | All BMAD skills (Claude Code) |
| `.git/hooks/prepare-commit-msg` | Auto-tags manual commits with AI trailers |
| `scripts/adoption-dashboard.sh` | Reads git trailers, prints adoption rates |

## Dashboard Usage

```bash
# All commits
bash scripts/adoption-dashboard.sh

# Filter by epic (story refs starting with "1-")
bash scripts/adoption-dashboard.sh "1-"
```

## Trailers Reference

| Trailer | Records | Values |
|---|---|---|
| `AI-Story` | Story authored with AI? | Tool/model, or `manual` |
| `AI-Code` | Code written with AI? | Tool/model, or `manual` |
| `AI-Test` | Tests written with AI? | Tool/model, or `manual` |
| `AI-Review` | Code reviewed by AI? | Tool/model, `manual`, or `pending` |
| `AI-Deploy` | Deployment automated? | `auto`, `manual-gate`, or `manual` |
| `AI-Model` | Primary model used | Model identifier, or `none` |
| `Story-Ref` | Story this commit belongs to | Story key from sprint plan |

## How It Flows

```
create-story  -->  fills AI-Story row in story file
     |
  dev-story   -->  fills AI-Code, AI-Test rows; commits with all trailers
     |
 code-review  -->  fills AI-Review row; amends trailer from "pending" to actual model
     |
 retrospective --> queries git for trailer data; surfaces adoption metrics in retro
```

Manual commits (hotfixes, config changes) get auto-tagged by the git hook with `manual` values.

## Modified Workflows (from upstream BMAD v6.3.0)

**Planning workflows** (auto-commit artifacts with AI trailers on completion):
- `bmad-create-prd` -- commits PRD on completion
- `bmad-create-epics-and-stories` -- commits epics on completion
- `bmad-create-architecture` -- commits architecture doc on completion
- `bmad-create-ux-design` -- commits UX design on completion
- `bmad-sprint-planning` -- commits sprint status on completion

**Development workflows** (AI Engineering Record + commit trailers):
- `bmad-create-story` -- AI Engineering Record table in template, commits story on creation
- `bmad-dev-story` -- fills record rows, creates commits with trailers, checklist updated
- `bmad-code-review` -- fills Code Review row, amends AI-Review trailer on commit
- `bmad-quick-dev` -- appends trailers to commits (both step-05 and one-shot paths)
- `bmad-retrospective` -- queries git for AI adoption metrics, includes in retro output
- `bmad-ai-tracking` -- new skill: hook template, dashboard, install instructions

## Credits

Built on [BMAD](https://github.com/bmad-code-org) v6.3.0 by the BMAD community. This fork adds the AI tracking layer. All upstream skills are included unmodified except where noted above.

## License

MIT. See [LICENSE](LICENSE).
