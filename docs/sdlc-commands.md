# BMAD SDLC Commands — What They Actually Do

Nine slash commands cover the full development lifecycle. They run in sequence. Each command reads the artifacts the previous one produced. A tenth command, `/auto-sprint`, automates the dev → test → review loop end-to-end.

```
create-prd → create-architecture → create-ux-design → create-epics-and-stories → sprint-planning
                                                                                        ↓
                                                                     (per story) create-story → dev-story → code-review → qa
```

**Column guide**

| Column | Meaning |
|--------|---------|
| Subagent | Whether the step spawns an independent AI agent with its own context window |
| Optimization | Any technique used to reduce token cost or context size |
| Artifact | File written or updated by this step |

---

## 1. `/create-prd`

Produces `_bmad-output/planning-artifacts/prd.md` via facilitated dialogue. The AI acts as a PM peer — asks structured questions, writes nothing until you've answered, and waits for your approval before moving to the next section.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Init — load config; detect if resuming an in-progress PRD | — | **Continuation detection**: resumes from exact last step; completed sections never rewritten | — |
| 2 | Classify product — type, domain, greenfield vs brownfield | — | **Step-file JIT**: only the current step's instructions are loaded into context | — |
| 2b | Product vision discovery — what makes this worth building | — | Step-file JIT | — |
| 2c | Draft executive summary from discovery so far | — | Step-file JIT | `_bmad-output/planning-artifacts/prd.md` (first write) |
| 3 | Define success criteria | — | Step-file JIT; **append-only**: new section added, existing content untouched | `_bmad-output/planning-artifacts/prd.md` |
| 4 | Map user journeys — every user type and their primary flows | — | Step-file JIT; append-only | `_bmad-output/planning-artifacts/prd.md` |
| 5 | Domain-specific requirements | — | **Conditional**: skipped entirely for low-complexity domains | `_bmad-output/planning-artifacts/prd.md` |
| 6 | Innovation discovery | — | **Conditional**: only runs if innovation signals detected in earlier steps | `_bmad-output/planning-artifacts/prd.md` |
| 7 | Project-type deep dive — type-specific requirements | — | Step-file JIT | `_bmad-output/planning-artifacts/prd.md` |
| 8 | Scoping — draw the MVP line, park the future list | — | Step-file JIT | `_bmad-output/planning-artifacts/prd.md` |
| 9 | Functional requirements — the capability contract for all downstream work | — | Step-file JIT | `_bmad-output/planning-artifacts/prd.md` |
| 10 | Non-functional requirements — performance, security, scale constraints | — | Step-file JIT | `_bmad-output/planning-artifacts/prd.md` |
| 11 | Polish — fix flow, reduce duplication across all sections | — | Reads full doc once; rewrites in place | `_bmad-output/planning-artifacts/prd.md` (final) |
| 12 | Handoff — validate completion, suggest next command | — | — | — |
| **Git** | **Commit `prd.md` with trailers: `AI-Phase: prd`, `AI-Tool`, `Story-Ref`** | — | Hook guards against duplicate tagging | **git log** |

---

## 2. `/create-architecture`

Produces `_bmad-output/planning-artifacts/architecture.md` — the technical blueprint every dev agent must follow. Collaborative step-by-step decisions; the AI searches the web for current versions at key decision points.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Init — load PRD and project context; detect if resuming | — | Continuation detection | — |
| 2 | Project context analysis — map PRD requirements to architectural concerns; for brownfield projects, read `graphify-out/GRAPH_REPORT.md` as ground truth of what already exists | — | Step-file JIT; **Graphify-aware** (brownfield only) | — |
| 3 | Starter template evaluation — options with current versions | — | Step-file JIT; web search for live framework versions | — |
| 4 | Core architectural decisions — tech stack, API design, data layer, auth | — | Step-file JIT; web search for current technology versions | `_bmad-output/planning-artifacts/architecture.md` |
| 4b | Optional decision-grill pass — pick `G` after any decision category to stress-test recommendations; `D` deepens to standard intensity, `R` to relentless | Grill skill | **Skipped by default**; only runs when user opts in. Light pass first; deeper passes layer on top | `_bmad-output/planning-artifacts/architecture.md` (decisions merged in place) |
| 5 | Implementation patterns and consistency rules — what every agent must do the same way | — | Step-file JIT | `_bmad-output/planning-artifacts/architecture.md` |
| 6 | Project structure and boundaries — full folder tree, component map, module boundaries | — | Step-file JIT | `_bmad-output/planning-artifacts/architecture.md` |
| 7 | Architecture validation — every PRD requirement must map to a decision | — | Step-file JIT | `_bmad-output/planning-artifacts/architecture.md` |
| 8 | Handoff — completion summary, link to epics workflow | — | — | `_bmad-output/planning-artifacts/architecture.md` (final) |
| **Git** | **Commit `architecture.md` with trailers: `AI-Phase: architecture`, `AI-Tool`, `Story-Ref`** | — | Hook guards against duplicate tagging | **git log** |

---

## 3. `/create-ux-design`

Produces `_bmad-output/planning-artifacts/ux-design-specification.md` plus HTML mockup files. Facilitated design exploration — the AI presents options at each decision point; you direct the direction.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Init — load PRD, architecture; detect if resuming | — | Continuation detection | — |
| 2 | Project understanding — clarify users, contexts, and key journeys | — | Step-file JIT | — |
| 3 | Core experience definition — platform targets, primary interaction model | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 4 | Desired emotional response — the feeling the product should leave users with | — | Step-file JIT; append-only | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 5 | UX pattern analysis — look at reference products, extract inspiration | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 6 | Design system choice — pick or define component library approach | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 7 | Defining core interaction — the one interaction that defines the product | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 8 | Visual foundation — color palette, typography, spacing system | — | Step-file JIT; append-only | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 9 | Design directions — present 2-3 distinct visual directions; you choose one | — | Step-file JIT | `ux-design-directions.html`, `ux-color-themes.html` |
| 10 | User journey flows — screen-by-screen flows for each primary journey | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 11 | Component strategy — custom vs library components; reuse rules | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 12 | UX consistency patterns — loading, errors, empty states, modals everywhere | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 13 | Responsive design and accessibility — breakpoints, WCAG targets | — | Step-file JIT | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| 14 | Handoff — finalize spec, ready for epics | — | — | `_bmad-output/planning-artifacts/ux-design-specification.md` (final) |
| **Git** | **Commit spec + HTML mockups with trailers: `AI-Phase: ux-design`, `AI-Tool`, `Story-Ref`** | — | Hook guards against duplicate tagging | **git log** |

---

## 4. `/create-epics-and-stories`

Produces `_bmad-output/planning-artifacts/epics.md` — all epics with BDD acceptance criteria and technical source hints. Reads all three planning docs, validates full requirement coverage before writing.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Validate prerequisites — confirm PRD, architecture, and UX exist; extract every functional and non-functional requirement | — | Step-file JIT | — |
| 2 | Design epic list — propose groupings ordered by user value; you approve or reshape | — | Step-file JIT | — |
| 3 | Generate all epics and stories — user story statement, BDD ACs, technical hints per story linking back to architecture | — | Step-file JIT; sequential per-epic processing keeps context bounded | `_bmad-output/planning-artifacts/epics.md` |
| 4 | Final validation — confirm every requirement from step 1 maps to at least one AC | — | Step-file JIT | `_bmad-output/planning-artifacts/epics.md` (final) |
| **Git** | **Commit `epics.md` with trailers: `AI-Phase: epics`, `AI-Tool`, `Story-Ref: epics`** | — | Hook guards against duplicate tagging | **git log** |

---

## 5. `/sprint-planning`

Produces `_bmad-output/implementation-artifacts/sprint-status.yaml` — the single tracking file that every downstream command (`create-story`, `dev-story`, `code-review`) reads and updates. Run once after epics are finalised; re-run any time to refresh auto-detected statuses.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Parse all epic files — extract epic numbers, story IDs, and titles; convert to kebab-case keys (e.g. `Story 1.1: User Auth` → `1-1-user-authentication`) | — | **Caveman lite** output mode; handles both whole `epics.md` and sharded `epic-1.md / epic-2.md` formats | — |
| 2 | Build sprint status structure — one entry per epic, one per story, one retrospective entry per epic; all default to `backlog` | — | Ordered output: epic → its stories → its retrospective → next epic | — |
| 3 | Apply intelligent status detection — checks if a story file already exists in `implementation/`; if so, upgrades status to at least `ready-for-dev`; never downgrades an existing status | — | **Preservation rule**: if existing `sprint-status.yaml` has a more advanced status, keeps it | — |
| 4 | Write `sprint-status.yaml` — full YAML with status definitions in comments and parseable key:value fields; metadata written twice (as comments for humans, as fields for parsers) | — | Incremental: only new entries added when re-run on an existing file | `_bmad-output/implementation-artifacts/sprint-status.yaml` |
| 5 | Validate and report — checks every epic and story from the epic files is present, all statuses are legal, file is valid YAML; prints counts | — | — | — |
| **Git** | **Commit `sprint-status.yaml` with trailers: `AI-Phase: sprint-plan`, `AI-Tool`, `Story-Ref: sprint-planning`** | — | Hook guards against duplicate tagging | **git log** |

---

## 6. `/create-story`

Produces `_bmad-output/implementation-artifacts/{story-key}.md` — a self-contained context file giving the dev agent everything it needs for one story: ACs, file locations, architecture guardrails, prior story learnings.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Find target story — reads `sprint-status.yaml` for the first backlog story, or takes one you specify | — | Sprint-status read once; auto-discovers next backlog story without iterating all files | — |
| 2 | Exhaustive artifact analysis — planning docs, previous story file, recent git commits | — | **SELECTIVE_LOAD**: only the epic-relevant sections of PRD/architecture/UX are loaded, not full documents; reads `GRAPH_REPORT.md` (no subprocess) | — |
| 3 | Architecture intelligence extraction — every constraint the developer must follow | — | Reads from already-loaded artifacts; zero extra file I/O | — |
| 4 | Web research for new dependencies | — | **Conditional gate**: skipped entirely if story adds no new library or major version upgrade | — |
| 5 | Write story file — ACs, dev notes, file locations, prior story learnings, open questions list | — | **Caveman lite** output mode | `_bmad-output/implementation-artifacts/{story-key}.md` |
| 5b | Resolve ambiguities collected during steps 2-4 via focused Q&A | Grill skill | **Skipped entirely** if zero open questions were collected | `_bmad-output/implementation-artifacts/{story-key}.md` (updated inline) |
| 6 | Update sprint-status to `ready-for-dev` | — | Targeted key update; full file structure preserved | `_bmad-output/implementation-artifacts/sprint-status.yaml` |
| **Git** | **Commit story file + sprint-status with trailers: `AI-Phase: story`, `AI-Tool`, `Story-Ref`** | — | Hook guards against duplicate tagging | **git log** |

---

## 7. `/dev-story`

Produces implemented, tested code. Fully autonomous once started — implements every task using red-green-refactor, runs tests after each task, does not stop until all ACs are satisfied or a hard blocker is hit.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Find next `ready-for-dev` story from sprint-status, or use the one specified | — | Reads sprint-status once; planning artifacts are NOT re-loaded (all context came via story file) | — |
| 2 | Load project context and parse all story sections | — | Only reads story file + `project-context.md`; no planning docs in context | — |
| 3 | Detect if resuming after a code review | — | **Conditional branch**: skips review-continuation setup entirely on fresh starts | — |
| 4 | Mark story `in-progress` in sprint-status | — | Targeted key update | `sprint-status.yaml` |
| 5 | Implement tasks in order — write failing test first (red), minimal code to pass (green), clean up (refactor) | — | **Graphify-aware**: reads `GRAPH_REPORT.md`; runs one orientation `query`, plus `explain` for each modified symbol before editing and `path` for cross-module impact checks; **Caveman ultra** output mode | Source code |
| 6 | Write unit, integration, and E2E tests for all changed behaviour | — | Scoped strictly to changed behaviour; no speculative test coverage | Test files |
| 7 | Run full test suite — zero regressions required before proceeding | — | Halts immediately on failure; never continues speculatively | — |
| 8 | Mark each task complete — only after all validation gates pass | — | Never marks partial completion; no lying about done status | `{story-key}.md` (checkboxes) |
| 9 | Mark story `review` in sprint-status; fill AI Engineering Record | — | — | `{story-key}.md`, `sprint-status.yaml` |
| 10 | One-line completion message; suggest running `/code-review` | — | Caveman ultra: minimal output | — |
| **Git** | **Commit all changed files with trailers: `AI-Phase: code`, `AI-Tool`, `Story-Ref`** | — | Hook guards against duplicate tagging | **git log** |

---

## 8. `/code-review`

Produces structured findings in the story file. Story moves to `done` (if all resolved) or back to `in-progress` with action items. Two git commits are made — one for patches applied, one for the review audit artifact.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 1 | Find review target — story in `review` status, explicit diff/branch/commit, or ask | — | Step-file JIT | — |
| 1 (cont.) | Construct diff; load spec; build blast radius context | — | **Graphify capped**: 1 aggregated query across all changed files; `explain` and `path` calls only on deep review request or god-node detected; **diff chunking** offered if diff >3000 lines | — |
| 2 | Launch review subagents in parallel | **Edge Case Hunter** (always); **Acceptance Auditor** (if spec exists); **Blind Hunter** (opt-in: say "deep", "blind", or "adversarial") | **Blind Hunter opt-in**: saves one full subagent on every routine review | — |
| 3 | Normalize all findings; deduplicate overlapping findings; classify as `patch`, `decision_needed`, `defer`, or `dismiss` | — | Dismissed findings dropped silently; dedup reduces noise before presenting to user | — |
| 4 | Resolve `decision_needed` items; offer to apply, walk through, or defer `patch` findings | — | Step-file JIT | `{story-key}.md` (findings inline), `deferred-work.md` |
| 4 (cont.) | Update story status; sync sprint-status | — | Targeted status update | `{story-key}.md`, `sprint-status.yaml` |
| 4 (cont.) | Persist review audit artifact | — | Always written even on clean review | `_bmad-output/implementation-artifacts/reviews/{story-key}-{date}.md` |
| **Git** | **Two commits: (1) patches applied — `AI-Phase: review`; (2) review audit artifact — `AI-Phase: review`. Both carry `AI-Tool` and `Story-Ref` trailers.** | — | Hook guards against duplicate tagging | **git log** |

---

## 9. `/qa` (generate-e2e-tests)

Produces automated test files that actually run. Scoped to one feature or directory at a time. Persists a run artifact on every invocation — even when no test file changed — so test execution is always traceable.

| Step | What happens | Subagent | Optimization | Artifact |
|------|-------------|:--------:|-------------|----------|
| 0 | Detect test framework — reads `package.json` or scans existing test files | — | Reuses existing patterns; no framework setup overhead if one found | — |
| 1 | Identify scope — specific feature, directory, or auto-discover | — | — | — |
| 2 | Generate API tests — status codes, response shape, happy path + critical error cases | — | **Focused scope**: happy path + 1-2 error cases only; no speculative edge coverage | Test files under `tests/` |
| 3 | Generate E2E tests — full user workflows using semantic locators | — | **Caveman lite** output; linear tests only, no complex fixture composition | Test files under `tests/` |
| 4 | Run tests; fix any failures before declaring done | — | Fixes inline rather than deferring | — |
| 5 | Write test summary; persist run artifact | — | **Run artifact always written** — even when no test file changed (appends fresh `Run-Timestamp`) | `_bmad-output/implementation-artifacts/tests/test-summary.md`, `_bmad-output/implementation-artifacts/tests/runs/{feature}-{date}.md` |
| **Git** | **Commit test files + run artifact with trailers: `AI-Phase: test`, `AI-Tool`, `Story-Ref`** | — | Hook guards against duplicate tagging | **git log** |

---

## 10. `/auto-sprint` (dontbmad-auto-sprint)

Automates the implementation loop: picks every `ready-for-dev` story from `stories/sprint-status.yaml` in order and runs three subagent phases per story — impl, test verification, and review — each in a fresh context window with a different model. Output is caveman-compressed; only failures expand.

**Prerequisites**

Auto-sprint assumes a zero-prompt run — anything missing causes it to either pause for permission, abort the loop, or corrupt the adoption history. Set all of the following before kicking off a sprint:

| Prerequisite | Why it matters | How to set it up |
|---|---|---|
| Claude Code **auto mode** enabled | Skips per-call tool approval. Without it the loop stalls on every `git commit`, `npx tsc`, and test run. | In Claude Code press <kbd>Shift</kbd>+<kbd>Tab</kbd> until the mode pill reads **auto**. (One press = auto-accept edits; second press = full auto.) The mode lasts for the session — re-enable each time you start auto-sprint. |
| `.claude/settings.json` `allowedTools` block | Pre-approves the exact bash commands the orchestrator and subagents need (git, tsc, vitest, graphify, npm/yarn/pnpm, ls, find, cat). Anything outside the list still prompts. | Copy the `allowedTools` snippet from `dontbmad-auto-sprint`'s SKILL.md, or run `/update-config` and say "add auto-sprint autonomous permissions". The skill writes the file for you. |
| `stories/sprint-status.yaml` exists | Single source of truth for which stories run and in what order. Auto-sprint reads it on every iteration. | Run `/sprint-planning` once after `/create-epics-and-stories`. Re-run any time epics change. |
| At least one story in `ready-for-dev` status | Each iteration picks the first story in that state. If none exist the loop reports "all done" and exits immediately. | Run `/create-story` for the next backlog story (it promotes the status), or edit `sprint-status.yaml` by hand. |
| Story spec at `stories/<story-key>.md` for every `ready-for-dev` entry | The impl agent reads this file as the only spec. Missing file → impl aborts on the first task. | Always run `/create-story` before flipping a story to `ready-for-dev`; never set the status manually without writing the spec first. |
| `prepare-commit-msg` hook installed in the repo | Stamps `AI-Tool: manual` on any commit that lacks trailers. Without it, mistyped commits during the run pollute the adoption dashboard with phantom phases. | Re-run `bash scripts/install.sh <workspace>` from the dont-b-mad source. The installer drops the hook into every git repo it finds in the workspace. |
| Pre-commit hooks pass on a clean checkout | Auto-sprint **never** uses `--no-verify`; a hook failure aborts the loop and surfaces the error. | Run your pre-commit suite (lint, format, etc.) on a clean tree before starting. Fix anything red. |
| `stories/auto-sprint.config.yaml` *(optional)* | Lets you pin per-phase models, tune auto-fix attempts, and skip the per-run pre-flight by setting `autonomous_mode.enabled: true`. | Copy the schema from the workflow file into `stories/auto-sprint.config.yaml`. Defaults apply when the file is absent. |
| `graphify-out/graph.json` *(optional, brownfield)* | Phase 0 BFS context fed to the impl agent. Absent or under 1KB → step skips silently with `(none, graph not built)`. | Run `uvx --from graphifyy graphify update .` at sprint start. Refresh on major refactors. |

> **Auto mode vs `autonomous_mode.enabled`** — these are different things and both matter. *Auto mode* is the Claude Code session toggle (Shift+Tab) that suppresses tool-permission prompts. *`autonomous_mode.enabled`* in `auto-sprint.config.yaml` skips the workflow's own pre-flight environment check at the start of each run. You generally want both on for an unattended sprint; flip one off if you want a confirmation step at the boundary.

**Invocation**

| Phrase | Behaviour |
|---|---|
| `run auto sprint` | Loop through all `ready-for-dev` stories until done or a failure |
| `auto dev next story` | Single-story iteration only |
| `run auto sprint --dry-run` | List next 3 stories; no implementation |
| `run auto sprint --model-impl=opus` | Override model for one phase |

**Per-story phases**

| Phase | Model | What happens | Subagent | Artifact |
|---|---|---|:---:|---|
| 0 — graph context | — | Run **one** graphify query using 3–5 short keywords from the story title (not a full sentence — graphify does BFS from node names). Accept first result even if empty; never retry. | — | `{graph_context}` variable |
| 1 — impl | `sonnet` | Read story spec; implement all ACs; write tests; run typecheck + test suite; output caveman | Yes | Source + test files; `stories/runs/<id>/impl.md` |
| 2 — test verify | `haiku` | Run typecheck + full test suite; report pass/fail counts only | Yes | `stories/runs/<id>/test.md` |
| 3 — review | `opus` | Diff review against ACs; surface blockers and notes only | Yes | `stories/runs/<id>/review.md` |

**Failure rules**

- Any phase failure → **abort loop**, surface output to user. Never auto-fix review blockers.
- Pre-commit hook failure → abort and surface; never skip with `--no-verify`.

**Commits (4 per story)**

```
feat: implement story <id> <short-title>
test: verify story <id> implementation
chore: record review for story <id>
chore: mark story <id> done in sprint status
```

---

## Caveman output mode

Several SDLC commands flip output into "caveman" mode — terse, fragmented prose that cuts output tokens roughly 75% while preserving full technical accuracy. Errors are quoted exactly; code blocks are unchanged.

**Three intensity levels**

| Level | What changes |
|-------|------------|
| `lite` | No filler, hedging, or pleasantries. Articles and full sentences kept. Tight but readable. |
| `full` (default) | Drops articles. Fragments OK. Short synonyms. Hard bans on "Let me X / I'll X / Sure / Furthermore" etc. |
| `ultra` | Abbreviates (DB / auth / cfg / req / res / fn / impl). Strips conjunctions. Arrows for causality (X → Y). One word when one word suffices. |

**Where it applies in the SDLC**

| Command / step | Level used |
|---|---|
| `/sprint-planning` step 1 (parse epics) | lite |
| `/create-story` step 5 (write story file) | lite |
| `/dev-story` step 5 (implementation) + step 10 (completion message) | ultra |
| `/qa` step 3 (E2E test generation) | lite |
| `/auto-sprint` (all phases — only failures expand) | full or stricter |

**Always exempt — normal prose used**

- BMAD deliverables: PRDs, architecture docs, UX specs, epics, story files. These are human documents.
- Code, commits, PR descriptions.
- Security warnings and irreversible-action confirmations.
- Cases where the user is confused and re-asking — clarity wins until the question is answered.

**Switching modes**

- Activate: `/dontbmad-caveman lite|full|ultra`, or natural triggers like "caveman mode", "talk like caveman", "be brief", "less tokens".
- Deactivate: "stop caveman" or "normal mode".
- Once on, the mode persists across every response in the session until explicitly turned off.

---

## Graphify integration

Several commands read a pre-built knowledge graph of the codebase to navigate without grepping blind. Built once via `uvx --from graphifyy graphify update .` (typically at sprint start) and refreshed on major refactors. Output goes to `graphify-out/`:

- `GRAPH_REPORT.md` — god nodes, community clusters, surprising dependencies. Cheap to read; loaded by every graph-aware step.
- `graph.json` — queryable graph used by `query`, `explain`, and `path` subcommands. Each call is a subprocess and is slower, so workflows cap usage.

If `graphify-out/` is absent, every workflow step that reads the graph skips it gracefully — nothing breaks.

**Where it applies**

| Command | What it reads | Why |
|---|---|---|
| `/create-architecture` step 2 | `GRAPH_REPORT.md` (brownfield only) | Ground truth of existing structure before designing changes |
| `/create-story` | `GRAPH_REPORT.md` + targeted `graph.json` lookups for modified code | Dev Notes with real file paths, function names, and callers |
| `/dev-story` step 5 | `GRAPH_REPORT.md` + one orientation `query` + `explain` per modified symbol + `path` for cross-module impact | Navigate to relevant files; treat callers as contract before editing |
| `/code-review` step 1 | `GRAPH_REPORT.md` + one aggregated `query` across all changed files. `explain` and `path` are opt-in for "deep" reviews or god-node hits | Compute blast radius — what depends on the changed files |
| `/auto-sprint` phase 0 | One `query` with 3–5 keywords pulled from the story title | BFS context for impl phase; first result accepted, no retries |

**Cost controls**

- `code-review` runs at most one aggregated `query` per review. Per-symbol `explain` and per-pair `path` calls require an explicit "deep" / "blind" / "adversarial" trigger or god-node detection.
- `auto-sprint` runs exactly one `query`, accepts the first result even if empty, and never retries.
- `create-story` queries are limited to the story's modified surface area, not the whole codebase.

**Common subcommands**

| Command | What it does |
|---|---|
| `uvx --from graphifyy graphify update .` | Build / rebuild the graph (incremental — only changed files re-processed) |
| `graphify query "<question>"` | BFS traversal of `graph.json` for a question; `--budget N` caps output tokens; `--dfs` for deeper traversal |
| `graphify explain "<node>"` | Plain-language explanation of a node and its direct neighbors |
| `graphify path "<A>" "<B>"` | Shortest path between two nodes |
| `graphify cluster-only .` | Re-cluster existing graph and regenerate the report |
| `graphify watch .` | Watch the folder and rebuild on code changes |

**When to rebuild**

| Trigger | Action |
|---|---|
| Sprint start | Full rebuild |
| New docs, specs, or design artifacts added | Full rebuild |
| Major refactor (new modules, renamed files) | Full rebuild |
| Day-to-day development | No rebuild — workflows read the existing graph |

---

## AIEye Live integration

Optional `PostToolUse` hook (`hooks/post-skill/`) that fires a celebration event to a team ingest endpoint when one of the SDLC skills completes. Fire-and-forget — foreground exits in under 50ms, network errors never fail the skill.

| Trigger skill | Event |
|---|---|
| `bmad-create-story` | `story_created` |
| `bmad-dev-story` | `story_developed` |
| `bmad-code-review` | `review_landed` |
| `bmad-qa-generate-e2e-tests` | `test_added` |

**Configuration** — `~/.claude/aieye-live.env` (mode 600). Required: `AIEYE_LIVE_INGEST_URL`, `AIEYE_LIVE_TOKEN`, `AIEYE_LIVE_ACTOR`. Optional: `AIEYE_LIVE_TEAM`, `AIEYE_LIVE_SKILLS` (allowlist), `AIEYE_LIVE_AI_TOOL`.

**Opt-out** — set `AIEYE_LIVE_STEALTH_MODE=true` to skip event publishing on a specific machine without removing the hook. Required env vars missing also short-circuits silently.

If the env file is absent the hook does nothing. No git operations, works outside any repository.

---

## Adoption tracking

Every command's final step commits to git with three trailers that feed the adoption dashboard:

```
AI-Phase: <prd|architecture|ux-design|epics|sprint-plan|story|code|review|test|deploy>
AI-Tool:  <agent and model that ran it, e.g. "cursor/claude-sonnet-4-20250514">
Story-Ref: <story key or phase name>
```

`deploy` is reserved by the dashboard (target 80%) but not auto-tagged by any workflow or by the `prepare-commit-msg` hook. The column will read `0/0` until a `/deploy` workflow exists or someone manually adds `AI-Phase: deploy` to deployment commits.

Manual commits in this repo are auto-tagged by the `prepare-commit-msg` hook (`AI-Phase: code`, `AI-Tool: manual`) so there are no gaps in the history. If a workflow already wrote trailers, the hook leaves them alone.

| Command | Reads | Writes | AI-Phase tag |
|---------|-------|--------|:------------:|
| `/create-prd` | Conversation | `_bmad-output/planning-artifacts/prd.md` | `prd` |
| `/create-architecture` | `prd.md` | `_bmad-output/planning-artifacts/architecture.md` | `architecture` |
| `/create-ux-design` | `prd.md`, `architecture.md` | `_bmad-output/planning-artifacts/ux-design-specification.md` | `ux-design` |
| `/create-epics-and-stories` | all three above | `_bmad-output/planning-artifacts/epics.md` | `epics` |
| `/sprint-planning` | `epics.md` | `_bmad-output/implementation-artifacts/sprint-status.yaml` | `sprint-plan` |
| `/create-story` | `epics.md` + planning docs + `sprint-status.yaml` | `_bmad-output/implementation-artifacts/{story}.md` | `story` |
| `/dev-story` | `{story}.md` + `sprint-status.yaml` | source code + tests | `code` |
| `/code-review` | git diff + `{story}.md` + `sprint-status.yaml` | findings in story file + review artifact | `review` |
| `/qa` | source code | test files + run artifact | `test` |

---

## AI Adoption Measurement

### How it works

Every commit made by an SDLC command carries three git trailers:

```
AI-Phase: story          ← which phase(s) of the lifecycle, comma-separated if mixed
AI-Tool:  cursor/claude-sonnet-4-20250514   ← which agent and model
Story-Ref: 1-2-user-authentication          ← which story
```

Manual commits (made by a developer outside any command) are auto-tagged by the `prepare-commit-msg` hook with `AI-Tool: manual`. The hook inspects the staged files and infers the phase — or a comma-separated list of phases when a commit touches multiple parts of the lifecycle:

| Staged files | AI-Phase tagged |
|---|---|
| `src/auth.ts` | `code` |
| `tests/auth.test.ts` | `test` |
| `_bmad-output/implementation-artifacts/1-2-user-auth.md` | `story` |
| `_bmad-output/implementation-artifacts/1-2-user-auth.md` + `src/auth.ts` | `story,code` |
| `_bmad-output/implementation-artifacts/1-2-user-auth.md` + `src/auth.ts` + `tests/auth.test.ts` | `story,test,code` |
| `_bmad-output/planning-artifacts/prd.md` | `prd` |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | `sprint-plan` |
| `_bmad-output/implementation-artifacts/reviews/1-2-auth-2026-05-06.md` | `review` |

If the hook sees trailers already present, it leaves them alone. This means **every commit is tagged** — there are no gaps in the denominator.

---

### The formula

The adoption dashboard (`scripts/adoption-dashboard.sh`) scans `git log --all`, reads the trailers, and for each phase calculates:

```
AI adoption % = (commits where AI-Tool ≠ "manual") / (all tagged commits for that phase) × 100
```

A commit is counted as **AI-authored** when `AI-Tool` is non-empty and is not `manual`.
A commit is counted as **manual** when `AI-Tool` is `manual` (hook-injected on developer commits).

When `AI-Phase` contains multiple values (e.g. `story,code`), the commit is counted independently in each phase's total. The overall unique-commit count at the bottom still counts it once. So a `story,code` commit adds 1 to `story_total` and 1 to `code_total` — the phase rates are always independent of each other.

The `[n/total]` breakdown in the dashboard output shows the raw numbers behind each percentage.

---

### Example output

```
======================================
  Pulse — AI Adoption Dashboard
======================================

  PLANNING (12 commits)
  --------------------------------
  prd                  100%  (target: 90%)  [3/3]
  architecture          100%  (target: 90%)  [2/2]
  ux-design            100%  (target: 90%)  [3/3]
  epics                100%  (target: 90%)  [1/1]
  sprint-plan          100%  (target: 90%)  [1/1]
  story                 83%  (target: 90%)  [5/6]

  DEVELOPMENT (18 commits)
  --------------------------------
  code                  75%  (target: 80%)  [12/16]
  test                  80%  (target: 85%)  [4/5]
  review               100%  (target: 95%)  [3/3]

  TOTAL: 30 tracked commits
======================================
```

A story at `83%` means 5 out of 6 story-creation commits were AI-authored — one story was created manually without running `/create-story`. A code phase at `75%` means some implementation commits were made outside `/dev-story`.

---

### Adoption targets

These are the targets set in the dashboard — the team is expected to meet or exceed them:

| Phase | Target | What it measures |
|-------|:------:|-----------------|
| `prd` | 90% | PRDs created via `/create-prd` |
| `architecture` | 90% | Architecture docs created via `/create-architecture` |
| `ux-design` | 90% | UX specs created via `/create-ux-design` |
| `epics` | 90% | Epics files created via `/create-epics-and-stories` |
| `sprint-plan` | 90% | Sprint status generated via `/sprint-planning` |
| `story` | 90% | Story files created via `/create-story` |
| `code` | 80% | Implementation commits from `/dev-story` |
| `test` | 85% | Test files generated via `/qa` |
| `review` | 95% | Reviews run via `/code-review` |
| `deploy` | 80% | Deployment commits — currently no workflow writes this; column stays empty until adopted |

Planning phases have a higher target (90%) because they are fully facilitated — there is no reason to do them manually. Code has a lower target (80%) because some hotfixes and config changes are legitimately faster to do by hand.

---

### Running the dashboard

```bash
# Current repo
bash scripts/adoption-dashboard.sh

# Filter to a specific story or epic
bash scripts/adoption-dashboard.sh "1-*"        # all stories in epic 1
bash scripts/adoption-dashboard.sh "1-2-*"      # specific story

# Across all repos in a workspace folder
bash scripts/adoption-dashboard.sh --workspace /path/to/workspace

# Specific repo
bash scripts/adoption-dashboard.sh --repo /path/to/repo
```

The workspace mode de-duplicates nested repos (submodules, vendored checkouts) so commits are never double-counted.
