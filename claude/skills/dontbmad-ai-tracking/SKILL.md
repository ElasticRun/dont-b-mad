# AI Tracking

Set up and query AI adoption tracking for the project. Use when the user says "set up AI tracking", "install AI hooks", or "show AI adoption metrics".

## What This Skill Does

1. Installs a `prepare-commit-msg` git hook that auto-tags manual commits with three trailers: `AI-Phase`, `AI-Tool`, `Story-Ref`.
2. Queries git history for AI adoption metrics grouped by SDLC phase and displays the Pulse dashboard.

## Trailer Scheme

Every commit gets exactly three trailers:

| Trailer | Purpose | Example values |
|---|---|---|
| `AI-Phase` | What phase this commit belongs to | `prd`, `architecture`, `ux-design`, `epics`, `sprint-plan`, `story`, `code`, `test`, `review`, `deploy` |
| `AI-Tool` | AI tool/model used, or `manual` | `cursor/claude-sonnet-4-20250514`, `manual` |
| `Story-Ref` | Story or artifact reference | `1-1-wave-planning`, `prd-aieye` |

## Usage

### Install the hook

```bash
cp .cursor/skills/dontbmad-ai-tracking/prepare-commit-msg .git/hooks/prepare-commit-msg
chmod +x .git/hooks/prepare-commit-msg
```

### Run Pulse (adoption dashboard)

```bash
bash .cursor/skills/dontbmad-ai-tracking/adoption-dashboard.sh           # all commits
bash .cursor/skills/dontbmad-ai-tracking/adoption-dashboard.sh "1-*"     # filter by Story-Ref
```
