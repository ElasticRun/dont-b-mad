# dontbmad-auto-sprint workflow

Auto-implement one (or more) `ready-for-dev` stories from `stories/sprint-status.yaml`. Each phase runs in a **fresh subagent** (via the `Agent` tool) so the orchestrator's context stays thin. Each phase uses a **different model** for cross-model verification.

## Config file

At startup the workflow reads `stories/auto-sprint.config.yaml` from the project root. If absent, all defaults apply. CLI flags override config file values.

**Schema** (copy this into your project's `stories/` directory to customize):

```yaml
# stories/auto-sprint.config.yaml

models:
  impl: sonnet       # implementation phase
  review: opus       # review phase — deeper reasoning, fresh eyes
  test: haiku        # test/verify phase — mechanical, cheapest

auto_fix:
  enabled: false     # when true, review blockers are fed back to a fix agent automatically
  max_attempts: 2    # max fix-loops per story before aborting (only relevant when enabled: true)
```

## Setup for fully autonomous operation

For a zero-prompt sprint run, the AI assistant needs pre-approved permissions so it never pauses to ask. Add the following to your IDE/assistant tool's settings (exact format depends on your tool):

Permissions needed:
- All `git` subcommands (status, add, commit, log, diff)
- `npx tsc`, `npx vitest`, `npm run *`, `yarn *`, `pnpm *`
- `uvx --from graphifyy graphify *`
- `find`, `ls`, `cat`

Once permissions are configured, set `autonomous_mode.enabled: true` in your `stories/auto-sprint.config.yaml` to skip the pre-flight check on every run.

## Model assignment (defaults)

| Phase | Default model | Reason |
|---|---|---|
| Implementation | `sonnet` | Fast, capable, good for well-specced stories |
| Review | `opus` | Deep reasoning, fresh eyes catch what impl missed |
| Test/verify | `haiku` | Mechanical (runs `tsc` + `vitest`), cheapest |

CLI flags override config: `--model-impl=opus --model-review=sonnet --model-test=haiku`

## Usage

- `run auto sprint` → loop through all `ready-for-dev` stories until done or a story fails
- `auto dev next story` → one iteration only
- `run auto sprint --dry-run` → list next 3 stories, don't implement
- `run auto sprint --model-impl=opus --model-review=sonnet` → override models for this run
- `run auto sprint --auto-fix` → enable auto-fix for this run (overrides config)

## Output style

**Caveman.** One line per phase. Only expand on failure.

```
[3/10] story 3-4-empty-data-states
  impl (sonnet)   ✓ 4 files changed
  test (haiku)    ✓ 245/245 pass, tsc clean
  review (opus)   ✓ no blockers
  commit          553b020
```

When auto-fix kicks in:

```
[3/10] story 3-4-empty-data-states
  impl (sonnet)   ✓ 4 files changed
  test (haiku)    ✗ 3 fail
  fix-1 (sonnet)  ✓ 2 files changed
  test (haiku)    ✓ 245/245 pass, tsc clean
  review (opus)   ✓ no blockers
  commit          553b020
```

## Workflow steps (per story)

### Step 0: Determine project root

Use the current working directory as the project root. All paths below are relative to it. Verify `stories/sprint-status.yaml` exists before proceeding.

### Step 0.5: Load config

Check if `stories/auto-sprint.config.yaml` exists. If it does, read it and extract:

- `models.impl` → `{model_impl}` (default: `sonnet`)
- `models.review` → `{model_review}` (default: `opus`)
- `models.test` → `{model_test}` (default: `haiku`)
- `auto_fix.enabled` → `{auto_fix_enabled}` (default: `false`)
- `auto_fix.max_attempts` → `{auto_fix_max_attempts}` (default: `2`)

Then apply CLI overrides on top:
- `--model-impl=X` → overrides `{model_impl}`
- `--model-review=X` → overrides `{model_review}`
- `--model-test=X` → overrides `{model_test}`
- `--auto-fix` flag → overrides `{auto_fix_enabled}` to `true`

Log resolved config in one line: `config: impl={model_impl} review={model_review} test={model_test} auto_fix={auto_fix_enabled}`

### Step 1: Pick next story

Read `stories/sprint-status.yaml`. Find the first story with status `ready-for-dev`, processing epics in order (1 → N). If none left, report "all done" and exit.

### Step 1.5: Graph context (skip if graph.json missing)

If `graphify-out/graph.json` exists, run **exactly one** query using 3–5 short keywords extracted from the story title (not a full sentence — graphify does BFS from node name matches, not semantic search):

```bash
uvx --from graphifyy graphify query --budget 1500 "<keyword1> <keyword2> <keyword3>" | head -80
```

Example: story "SSE stream endpoint with display token verification" → query `"display_token sse ingest auth"`

Save the first 80 lines of stdout as `{graph_context}` (already capped by `head -80`). Accept whatever comes back — even "No matching nodes found". **Do NOT retry.** If the file does not exist, set `{graph_context}` = `(none, graph not built)` and continue.

### Step 2: Implementation (fresh agent, `{model_impl}`)

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `{model_impl}`
- `description`: "Implement story <id>"
- `prompt`:

```
Implement story <id> for the project at <project-root>.

OUTPUT RULE (non-negotiable): Do NOT write any text between tool calls. No narration, no "let me check", no step announcements. Work silently. Only write text ONCE at the very end, in this exact format:

files: <list>
tests: <X pass / Y fail>
issues: <none or one-line description>

RULES:
- Read story spec first: stories/<story-file>.md
- Read referenced source files before changes
- For docs/architecture.md and docs/ux-design-specification.md (if they exist): if the file is under 150 lines read it fully; otherwise grep for sections relevant to your story domain rather than reading the whole file
- Implement fully per acceptance criteria
- Write tests for new functionality (co-located *.test.ts or equivalent)
- Run typecheck and test commands per project conventions (e.g. `npx tsc --noEmit` + `npx vitest run`)
- Follow existing code patterns and conventions
- If GRAPH CONTEXT below is non-empty, treat its file paths and dependencies as authoritative starting points. Do not invent paths.
- Before modifying any function or class, run `uvx --from graphifyy graphify explain "<symbol>"` to see direct callers/callees. For impact between two symbols, run `uvx --from graphifyy graphify path "<A>" "<B>"`. Skip silently if graph.json is absent.
- Do NOT commit

GRAPH CONTEXT:
{graph_context}
```

Capture result. Retain only the final summary block (the `files/tests/issues` lines) — this is the only part that needs to persist in orchestrator context. If agent reports failure/errors, **abort the loop** and surface the issue to the user.

### Step 3: Test verification (fresh agent, `{model_test}`)

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `{model_test}`
- `description`: "Verify tests for story <id>"
- `prompt`:

```
Run typecheck and tests in <project-root>. No text between tool calls — work silently. Output exactly this at the end and nothing else:

typecheck: pass | fail
tests: X/Y pass
<first 25 error lines if either failed — truncate beyond that>
```

If either fails:
- If `{auto_fix_enabled}` is `true` and current fix attempt count < `{auto_fix_max_attempts}`: go to **Step 3.5**
- Otherwise: abort loop, surface output to user

### Step 3.5: Auto-fix test failures (only when `{auto_fix_enabled}` is `true`)

Increment fix attempt counter (starting at 1). If counter > `{auto_fix_max_attempts}`, abort and surface errors.

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `{model_impl}`
- `description`: "Fix story <id> (attempt <N>)"
- `prompt`:

```
Fix test/typecheck failures in <project-root> for story <id>.

OUTPUT RULE: Work silently. No text between tool calls. Write only at the very end:

files: <list>
tests: <X pass / Y fail>
issues: <none or one-line description>

RULES:
- Story spec: stories/<story-file>.md
- Read current test output below and trace failures to root cause
- Fix only what is broken — do not rewrite unrelated code
- Re-run typecheck and tests after each fix to confirm resolution
- Do NOT commit

FAILURES TO FIX (first 25 lines):
{test_output_from_step_3}
```

Then loop back to **Step 3** (re-verify).

### Step 4: Review (fresh agent, `{model_review}`)

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `{model_review}`
- `description`: "Review story <id> implementation"
- `prompt`:

```
Review staged + unstaged changes in <project-root> for story <id>. Story spec: stories/<story-file>.md

No text between tool calls — work silently. Output exactly this at the end and nothing else:

BLOCKERS: <none | bullet list of must-fix items>
NOTES: <none | brief non-blocking observations>
```

If review returns blockers:
- If `{auto_fix_enabled}` is `true` and current fix attempt count < `{auto_fix_max_attempts}`: go to **Step 4.5**
- Otherwise: abort loop, surface them to user

### Step 4.5: Auto-fix review blockers (only when `{auto_fix_enabled}` is `true`)

Increment fix attempt counter. If counter > `{auto_fix_max_attempts}`, abort and surface blockers.

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `{model_impl}`
- `description`: "Fix review blockers for story <id> (attempt <N>)"
- `prompt`:

```
Fix the code review blockers listed below for story <id> in <project-root>.

OUTPUT RULE: Work silently. No text between tool calls. Write only at the very end:

files: <list>
issues: <none or one-line description>

RULES:
- Story spec: stories/<story-file>.md
- Address every BLOCKER item below — do not skip any
- Do not change unrelated code
- Re-run typecheck and tests after fixes to confirm nothing broke
- Do NOT commit

BLOCKERS TO FIX (max 30 lines):
{blockers_from_step_4}
```

Then loop back to **Step 3** (re-verify tests, then re-review).

### Step 5: Commit

Stage only the files the impl/fix agents touched. Commit with message:

```
feat: implement story <id> <short-title>

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step 6: Update sprint status

Edit `stories/sprint-status.yaml`: change the story's status from `ready-for-dev` to `done`.

### Step 7: Loop or stop

Append one row to the in-context sprint log: `<id> | <commit> | impl✓ | test✓ | review✓`. This compact table is the only sprint-level state that must persist across stories — do not carry prior agent outputs forward.

If user invoked with `run auto sprint` (not `auto dev next story`), jump back to Step 1. Otherwise stop.

## Notes

- **Never skip hooks.** If pre-commit fails, abort and surface.
- **Auto-fix is opt-in.** Without `auto_fix.enabled: true` in config (or `--auto-fix` flag), review blockers still abort and surface to the user. Cross-model review exists to catch real issues — auto-fix only makes sense when you've tuned your story specs well enough to trust the loop.
- **Fix attempt counter resets per story.** `max_attempts` applies independently to each story, not the whole sprint run.
- **Caveman output at every level.** User is running this to save tokens, not read prose.
- **Orchestrator touches no source files directly.** All impl/fix/review runs in subagents.
- **Keep orchestrator context lean.** After each agent call, retain only the compact summary (3–4 lines). Do not carry full agent output forward — the sprint log table is the only cross-story state.
- **Project-agnostic.** This skill works on any project that has `stories/sprint-status.yaml` and story spec files in `stories/`.
