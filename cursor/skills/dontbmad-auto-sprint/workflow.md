# dontbmad-auto-sprint workflow

Auto-implement one (or more) `ready-for-dev` stories from `stories/sprint-status.yaml`. Each phase runs in a **fresh subagent** (via the `Agent` tool) so the orchestrator's context stays thin. Each phase uses a **different model** for cross-model verification.

## Model assignment (defaults)

| Phase | Model | Reason |
|---|---|---|
| Implementation | `sonnet` | Fast, capable, good for well-speced stories |
| Review | `opus` | Deep reasoning, fresh eyes catch what impl missed |
| Test/verify | `haiku` | Mechanical (runs `tsc` + `vitest`), cheapest |

The user can override with `models: impl=X review=Y test=Z` in the invocation.

## Usage

- `run auto sprint` → loop through all `ready-for-dev` stories until done or a story fails
- `auto dev next story` → one iteration only
- `run auto sprint --dry-run` → list next 3 stories, don't implement
- `run auto sprint --model-impl=opus --model-review=sonnet` → override models

## Output style

**Caveman.** One line per phase. Only expand on failure.

```
[3/10] story 3-4-empty-data-states
  impl (sonnet)   ✓ 4 files changed
  test (haiku)    ✓ 245/245 pass, tsc clean
  review (opus)   ✓ no blockers
  commit          553b020
```

## Workflow steps (per story)

### Step 0: Determine project root

Use the current working directory as the project root. All paths below are relative to it. Verify `stories/sprint-status.yaml` exists before proceeding.

### Step 1: Pick next story

Read `stories/sprint-status.yaml`. Find the first story with status `ready-for-dev`, processing epics in order (1 → N). If none left, report "all done" and exit.

### Step 2: Implementation (fresh agent, `sonnet`)

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `sonnet` (or user override)
- `description`: "Implement story <id>"
- `prompt`:

```
Implement story <id> for the project at <project-root>.

RULES:
- Read story spec first: stories/<story-file>.md
- Read referenced source files before changes
- Read docs/architecture.md + docs/ux-design-specification.md for guidance (if they exist)
- Implement fully per acceptance criteria
- Write tests for new functionality (co-located *.test.ts or equivalent)
- Run typecheck and test commands per project conventions (e.g. `npx tsc --noEmit` + `npx vitest run`)
- Follow existing code patterns and conventions
- Do NOT commit
- Output CAVEMAN style: list files changed, test result line, any issues. No explanations.
```

Capture result. If agent reports failure/errors, **abort the loop** and surface the issue to the user.

### Step 3: Test verification (fresh agent, `haiku`)

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `haiku`
- `description`: "Verify tests for story <id>"
- `prompt`:

```
Run typecheck and tests in <project-root> and report results.

Look at package.json scripts to determine the correct commands (typically `npx tsc --noEmit` and `npx vitest run`, or `npm test`).

Report ONLY:
- typecheck: pass/fail (with first 10 lines of errors if fail)
- tests: X/Y tests pass (with failing test names if any)

No other output.
```

If either fails, abort loop, surface output to user.

### Step 4: Review (fresh agent, `opus`)

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `opus`
- `description`: "Review story <id> implementation"
- `prompt`:

```
Review the staged + unstaged changes in <project-root> for story <id>.

Story spec: stories/<story-file>.md

Check:
- Does implementation match acceptance criteria?
- Edge cases handled? (empty states, errors, boundaries)
- Follows existing code patterns?
- Any security issues? (XSS, injection, unsafe DOM ops)
- Any obvious bugs?

Output:
- `BLOCKERS:` list anything that must be fixed (or `none`)
- `NOTES:` optional non-blocking observations (keep brief)

CAVEMAN style. No other output.
```

If review returns blockers, abort loop, surface them to user. (Do NOT auto-fix — user decides.)

### Step 5: Commit

Stage only the files the impl agent touched. Commit with message:

```
feat: implement story <id> <short-title>

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step 6: Update sprint status

Edit `stories/sprint-status.yaml`: change the story's status from `ready-for-dev` to `done`.

### Step 7: Loop or stop

If user invoked with `run auto sprint` (not `auto dev next story`), jump back to Step 1. Otherwise stop.

## Notes

- **Never skip hooks.** If pre-commit fails, abort and surface.
- **Never auto-fix review blockers.** Cross-model review exists to catch issues — silencing them defeats the purpose.
- **Caveman output at every level.** User is running this to save tokens, not read prose.
- **Orchestrator touches no source files directly.** All impl/review runs in subagents.
- **Project-agnostic.** This skill works on any project that has `stories/sprint-status.yaml` and story spec files in `stories/`.
