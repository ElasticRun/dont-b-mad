# dontbmad-auto-sprint workflow

Auto-implement one (or more) `ready-for-dev` stories from `{implementation_artifacts}/sprint-status.yaml`. Impl and review run in **fresh subagents** (via the `Agent` tool) so the orchestrator's context stays thin. Test verification runs **inline** in the orchestrator — subagent dispatch overhead exceeded the actual `tsc` + test work.

## Config file

At startup the workflow reads `{implementation_artifacts}/auto-sprint.config.yaml` from the project root. If absent, all defaults apply. CLI flags override config file values.

**Schema** (copy this into your project's `{implementation_artifacts}/` directory to customize):

```yaml
# {implementation_artifacts}/auto-sprint.config.yaml

models:
  impl: sonnet       # implementation phase
  review: sonnet     # review phase — sonnet is fast and capable enough; switch to opus only if review keeps missing real issues
  # test phase runs inline in the orchestrator (no subagent)

auto_fix:
  enabled: true      # auto-feed test/review blockers to a fix agent. Set false to require human triage.
  max_attempts: 2    # max fix-loops per story before aborting
```

## Setup for fully autonomous operation

For a zero-prompt sprint run, Claude Code needs pre-approved permissions so it never pauses to ask. Add the following `allowedTools` block to your project's `.claude/settings.json` (create the file if it doesn't exist):

```json
{
  "allowedTools": [
    "Bash(git status*)",
    "Bash(git add*)",
    "Bash(git commit*)",
    "Bash(git log*)",
    "Bash(git diff*)",
    "Bash(npx tsc*)",
    "Bash(npx vitest*)",
    "Bash(npm run*)",
    "Bash(yarn*)",
    "Bash(pnpm*)",
    "Bash(uvx --from graphifyy graphify*)",
    "Bash(find .*)",
    "Bash(ls*)",
    "Bash(cat*)"
  ]
}
```

You can also run `/update-config` in Claude Code and say "add auto-sprint autonomous permissions" — it will write the settings file for you.

Once the settings file is in place, set `autonomous_mode.enabled: true` in your `{implementation_artifacts}/auto-sprint.config.yaml` to skip the pre-flight check on every run.

## Model assignment (defaults)

| Phase | Default | Reason |
|---|---|---|
| Implementation | `sonnet` (subagent) | Fast, capable, good for well-specced stories |
| Test/verify | inline Bash in orchestrator | Mechanical (`tsc` + `vitest`); subagent dispatch overhead exceeds the work |
| Review | `sonnet` (subagent) | Cross-agent fresh eyes; sonnet is fast and catches real issues. Use `--model-review=opus` for deeper review when stakes are high |

CLI flags override config: `--model-impl=opus --model-review=opus`

## Usage

- `run auto sprint` → loop through all `ready-for-dev` stories until done or a story fails
- `auto dev next story` → one iteration only
- `run auto sprint --dry-run` → list next 3 stories, don't implement
- `run auto sprint --model-impl=opus --model-review=opus` → override models for this run
- `run auto sprint --no-auto-fix` → disable auto-fix for this run (overrides config)

## Output style

**Caveman.** One line per phase. Only expand on failure.

```
[3/10] story 3-4-empty-data-states
  impl (sonnet)   ✓ 4 files changed
  test (inline)   ✓ 245/245 pass, tsc clean
  review (sonnet) ✓ no blockers
  commit          553b020
```

When auto-fix kicks in:

```
[3/10] story 3-4-empty-data-states
  impl (sonnet)    ✓ 4 files changed
  test (inline)    ✗ 3 fail
  fix-1 (sonnet)   ✓ 2 files changed
  test (inline)    ✓ 245/245 pass, tsc clean
  review (sonnet)  ✓ no blockers
  commit           553b020
```

## Workflow steps (per story)

### Step 0: Determine project root and resolve paths

Use the current working directory as the project root. All paths below are relative to it.

Resolve `{implementation_artifacts}` from `{project-root}/_bmad/bmm/config.yaml`. The value will look like `{project-root}/_bmad-output/implementation-artifacts`. Strip the `{project-root}/` prefix to get a project-relative path.

If `{project-root}/_bmad/bmm/config.yaml` does not exist OR has no `implementation_artifacts` key, **abort and surface the missing prerequisite** to the user. Tell them to run `bash <dont-b-mad-source>/scripts/install.sh <workspace>` to scaffold the BMAD layout. Do NOT fall back to any other path — there is exactly one valid location for sprint state and story files.

Verify `{implementation_artifacts}/sprint-status.yaml` exists before proceeding. If not, report missing prerequisite and exit.

### Step 0.5: Load auto-sprint config

Check if `{implementation_artifacts}/auto-sprint.config.yaml` exists. If it does, read it and extract:

- `models.impl` → `{model_impl}` (default: `sonnet`)
- `models.review` → `{model_review}` (default: `sonnet`)
- `auto_fix.enabled` → `{auto_fix_enabled}` (default: `true`)
- `auto_fix.max_attempts` → `{auto_fix_max_attempts}` (default: `2`)

Then apply CLI overrides on top:
- `--model-impl=X` → overrides `{model_impl}`
- `--model-review=X` → overrides `{model_review}`
- `--auto-fix` flag → forces `{auto_fix_enabled}` to `true`
- `--no-auto-fix` flag → forces `{auto_fix_enabled}` to `false`

Resolve short model aliases to full model ids for AI-tracking trailers (used in Steps 5–8):
- `sonnet` → `claude-sonnet-4-6`
- `opus` → `claude-opus-4-7`
- `haiku` → `claude-haiku-4-5`
- any other value → use verbatim

Also capture `{orchestrator_model}` = the full model id of the agent running this skill (read from your own runtime context, e.g. `claude-opus-4-7`). Used in Steps 6 and 8 commit trailers.

Log resolved config in one line: `config: impl={model_impl} review={model_review} auto_fix={auto_fix_enabled}`

### Step 1: Pick next story

Read `{implementation_artifacts}/sprint-status.yaml`. Find the first story with status `ready-for-dev`, processing epics in order (1 → N). If none left, report "all done" and exit.

### Step 1.5: Graph context (skip aggressively)

**Early-exit checks (in order — first match wins):**

1. If `graphify-out/graph.json` does not exist OR is smaller than 1KB → set `{graph_context}` = `(none, graph not built)` and continue. Do not run any query.
2. Otherwise run **exactly one** query using 3–5 short keywords from the story title (graphify does BFS from node name matches, not semantic search):

```bash
uvx --from graphifyy graphify query --budget 1500 "<keyword1> <keyword2> <keyword3>" | head -80
```

Example: story "SSE stream endpoint with display token verification" → query `"display_token sse ingest auth"`

3. If the query output contains `"No matching nodes found"`, is empty, or is fewer than 5 non-blank lines → set `{graph_context}` = `(none, no graph hits)` and continue.
4. Otherwise save stdout as `{graph_context}`.

**Hard rule:** never run a second graph query in this step, never rephrase, never retry. The orchestrator's job here is to either grab usable context cheaply or skip. Spending more than 5 seconds on graphify defeats its purpose.

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
- Read story spec first: {implementation_artifacts}/<story-file>.md
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

Capture result. Retain only the final summary block (the `files/tests/issues` lines) — the full agent output is not needed beyond this. If agent reports failure/errors, **abort the loop** and surface the issue to the user.

Then write implementation artifact:

- Path: `{implementation_artifacts}/runs/<story-id>/impl.md`
- Include:
  - story id + title
  - model used
  - files changed (from impl output)
  - impl test line from impl output
  - timestamp

### Step 3: Test verification (inline Bash, no subagent)

This phase runs in the orchestrator. Subagent dispatch overhead is ~10s; the actual work (running `tsc` + tests) is faster than the dispatch, so inlining wins.

**Resolve commands once per sprint** (cache across stories):

1. If `package.json` has a `scripts.typecheck` entry → `{tc_cmd}` = `npm run typecheck`. Else if `tsconfig.json` exists → `{tc_cmd}` = `npx tsc --noEmit`. Else → `{tc_cmd}` = `(skip)`.
2. If `package.json` has `scripts.test` → `{test_cmd}` = `npm test --silent`. Else if vitest is in deps → `{test_cmd}` = `npx vitest run`. Else → `{test_cmd}` = `(skip)`.
3. Non-Node projects: detect by `pyproject.toml` (`pytest`), `Cargo.toml` (`cargo test`), `go.mod` (`go test ./...`), etc. If no test runner detectable, set `{test_cmd}` = `(skip)` and warn once.

**Run them** (each in its own Bash call so partial failure is visible):

```bash
{tc_cmd} 2>&1 | tail -30
```

```bash
{test_cmd} 2>&1 | tail -40
```

Parse exit codes. Build `{test_output}` = the concatenated tails (max ~70 lines).

If typecheck failed OR tests failed:
- If `{auto_fix_enabled}` is `true` and current fix attempt count < `{auto_fix_max_attempts}`: go to **Step 3.5**
- Otherwise: abort loop, print `{test_output}` to user

Then write test artifact:

- Path: `{implementation_artifacts}/runs/<story-id>/test.md` (append if file exists — prefix with `## Attempt <N>`)
- Include:
  - story id + title
  - phase: `inline`
  - typecheck result + command used
  - test result + command used
  - failing names / first errors when present
  - timestamp

### Step 3.5: Auto-fix (only when `{auto_fix_enabled}` is `true`)

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
- Story spec: {implementation_artifacts}/<story-file>.md
- Read current test output below and trace failures to root cause
- Fix only what is broken — do not rewrite unrelated code
- Re-run typecheck and tests after each fix to confirm resolution
- Do NOT commit

FAILURES TO FIX (first 25 lines):
{test_output}
```

Then loop back to **Step 3** (re-verify).

### Step 4: Review (fresh agent, `{model_review}`)

Spawn Agent with these params:
- `subagent_type`: `general-purpose`
- `model`: `{model_review}`
- `description`: "Review story <id> implementation"
- `prompt`:

```
Review staged + unstaged changes in <project-root> for story <id>. Story spec: {implementation_artifacts}/<story-file>.md

No text between tool calls — work silently. Output exactly this at the end and nothing else:

BLOCKERS: <none | bullet list of must-fix items>
NOTES: <none | brief non-blocking observations>
```

If review returns blockers:
- If `{auto_fix_enabled}` is `true` and current fix attempt count < `{auto_fix_max_attempts}`: go to **Step 4.5**
- Otherwise: abort loop, surface them to user

Then write review artifact:

- Path: `{implementation_artifacts}/runs/<story-id>/review.md` (append if file exists — prefix with `## Attempt <N>`)
- Include:
  - story id + title
  - model used
  - `BLOCKERS` section
  - `NOTES` section
  - timestamp

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
- Story spec: {implementation_artifacts}/<story-file>.md
- Address every BLOCKER item below — do not skip any
- Do not change unrelated code
- Re-run typecheck and tests after fixes to confirm nothing broke
- Do NOT commit

BLOCKERS TO FIX (max 30 lines):
{blockers_from_step_4}
```

Then loop back to **Step 3** (re-verify tests, then re-review).

### Step 5: Commit implementation phase

Stage only:

- files the impl agent touched
- `{implementation_artifacts}/runs/<story-id>/impl.md`

Commit message (substitute `{model_impl}` with the resolved value, e.g. `claude-sonnet-4-6`, `claude-opus-4-7`):

```
feat: implement story <id> <short-title>

AI-Phase: code
AI-Tool: cli/claude-{model_impl}
Story-Ref: <id>
```

### Step 6: Commit test evidence

Stage:

- `{implementation_artifacts}/runs/<story-id>/test.md`

Commit message (test phase ran inline in the orchestrator — substitute `{orchestrator_model}` with the model running the orchestrator, e.g. `claude-opus-4-7`):

```
test: verify story <id> implementation

AI-Phase: test
AI-Tool: cli/claude-{orchestrator_model}
Story-Ref: <id>
```

### Step 7: Commit review evidence

Stage:

- `{implementation_artifacts}/runs/<story-id>/review.md`

Commit message (substitute `{model_review}` with the resolved value):

```
chore: record review for story <id>

AI-Phase: review
AI-Tool: cli/claude-{model_review}
Story-Ref: <id>
```

### Step 8: Update sprint status

Edit `{implementation_artifacts}/sprint-status.yaml`: change story status from `ready-for-dev` to `done`.

Commit message (sprint-status edit done by the orchestrator):

```
chore: mark story <id> done in sprint status

AI-Phase: sprint-plan
AI-Tool: cli/claude-{orchestrator_model}
Story-Ref: <id>
```

### Step 9: Loop or stop

Append one row to the in-context sprint log: `<id> | <commit> | impl✓ | test✓ | review✓`. This compact table is the only sprint-level state that must persist across stories — do not carry prior agent outputs forward. The artifact files in `{implementation_artifacts}/runs/` are the authoritative record; the orchestrator does not need to hold that detail in context.

If user invoked with `run auto sprint` (not `auto dev next story`), jump back to Step 1. Otherwise stop.

## Notes

- **Never skip hooks.** If pre-commit fails, abort and surface.
- **AI-tracking trailers are mandatory** on all four step commits (5–8). If `AI-Phase:` is missing, the project's `prepare-commit-msg` hook stamps `AI-Tool: manual`, which corrupts the adoption dashboard. Substitute the resolved model id, never leave `{model_impl}`/`{model_review}`/`{orchestrator_model}` literal.
- **Auto-fix is on by default.** Bounded by `max_attempts: 2`. To require human triage on every blocker, set `auto_fix.enabled: false` or pass `--no-auto-fix`.
- **Fix attempt counter resets per story.** `max_attempts` applies independently to each story, not the whole sprint run.
- **Caveman output at every level.** User is running this to save tokens, not read prose.
- **Orchestrator touches source files only during inline test verification.** Impl/fix/review still run in fresh subagents.
- **Verify phase is inline, not a subagent.** Subagent dispatch overhead (~10s) exceeded the actual work (`tsc` + tests). Running it in the orchestrator saves ~50s per story.
- **Review phase keeps `general-purpose` subagent.** `Explore` is read-only and reads excerpts, not full files — wrong fit for code review per its own docs.
- **Cross-model review is optional, not default.** Default review model is `sonnet` (same family as impl). If you're seeing review-misses on non-trivial stories, flip to `--model-review=opus` for the high-stakes runs.
- **Keep orchestrator context lean.** After each agent call, retain only the compact summary (3–4 lines). Do not carry full agent output forward — use `{implementation_artifacts}/runs/<id>/` artifact files as the authoritative record.
- **Project-agnostic.** Works on any project with `{implementation_artifacts}/sprint-status.yaml` and story spec files in `{implementation_artifacts}/`.
- **No empty commits.** If a phase artifact is unchanged, append a fresh timestamp line so git history still records phase execution.

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
AIEYE_HOOK="$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && AIEYE_LIVE_SKILL=dontbmad-auto-sprint "$AIEYE_HOOK" || true
```

Uses the same ingest URL and payload logic as `~/.claude/hooks/aieye-live/lib/dispatch.js` (deployed from `hooks/post-skill/` via `scripts/install.sh`; see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

