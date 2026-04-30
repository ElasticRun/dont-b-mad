---
name: dontbmad-grill
description: >
  Interview the user relentlessly on a plan, decision, or artifact until every branch
  of the decision tree is resolved. One question at a time, with a recommended answer
  for each. Reads existing artifacts and codebase before asking. Use when the user
  says "grill me", "stress-test this plan", "interrogate this", or when invoked from
  a BMAD planning skill (architecture, PRD, story, UX) before finalizing the artifact.
---

# Grill

Adapted from [grill-me](https://github.com/mattpocock/skills/tree/main/skills/productivity/grill-me) by Matt Pocock. MIT license.

**Goal:** Resolve every load-bearing decision in a plan before code or document gets written. Surface unspoken assumptions, force one decision at a time, recommend a default for each.

## When to Use

- User invokes `/dontbmad-grill` directly, or asks to "grill me", "stress-test", "interrogate this plan"
- A BMAD planning skill (architecture, PRD, story, UX) calls this skill before finalizing an artifact
- The user pauses on a complex decision and asks for help deciding

## When NOT to Use

- Brainstorming or divergent thinking. This is convergent; use `bmad-brainstorming` instead.
- Code review or implementation review. Use `bmad-code-review` or `bmad-review-adversarial-general`.
- The artifact is already complete and the user just wants validation. Use `bmad-validate-prd` or `bmad-check-implementation-readiness`.

## Core Rules

1. **One question at a time.** Never compound. Never list five questions and ask the user to pick. Single question, single recommended answer, wait for response.

2. **Recommend an answer with every question.** Default mode is review-and-confirm, not blank-page elicitation. State the recommendation, state the reason in one line, then ask.

3. **Walk the decision tree, not a checklist.** Start at the root decision. Resolve it. Then surface the children that depend on that resolution. Don't ask about leaves before their parents are settled.

4. **Read before you ask.** Before asking the user anything, check:
   - The current artifact draft (architecture.md, prd.md, story file, etc.)
   - `{project_knowledge}/project-context.md` if it exists
   - The codebase itself if the question is about existing patterns
   - Prior planning artifacts in `{planning_artifacts}/`
   If the answer is already there, do not ask. State it, confirm it, move on.

5. **Surface dependencies as you go.** When a decision unlocks a downstream decision, name it: "This means we'll also need to settle X next." Don't batch them, just signal what's coming.

6. **Stop when the tree is resolved.** Don't grill for the sake of grilling. When every branch reachable from the current root has a settled answer, return to the calling skill or end the session.

## Inputs

When invoked from another skill, accept:
- `topic` — the artifact, decision, or section being grilled (e.g., "data architecture for the wave planning epic")
- `draft_so_far` — current state of the artifact, if any
- `intensity` — `light` (3-5 questions, only critical branches), `standard` (every load-bearing branch), `relentless` (every branch including nice-to-haves)

**Default intensity by invocation path:**
- Direct user invocation (`/dontbmad-grill`, "grill me"): `standard`. The user opted in; give them the full thing.
- Auto-invocation from another skill: `light`. The user pressed `G` on a menu, not "grill me into oblivion." If they want more, the calling skill prompts them to escalate after the light pass returns.

When invoked directly by the user, infer the topic and draft from conversation context. Ask once if unclear, then proceed.

## Flow

### Step 1: Build the Tree

Read the inputs above. Identify the root decision and its children. Do not show the full tree to the user; keep it internal. The tree is your traversal order, not a deliverable.

Count the unresolved nodes the current intensity will hit. This is the question budget — used in the question template below so the user can pace themselves. Recompute when the tree changes (loop detection, deferred decisions).

If working inside a BMAD planning skill, the calling skill provides the topic. If invoked directly, ask one clarifying question to scope the topic, then proceed.

### Step 2: Traverse

For each unresolved node, depth-first:

1. Check if any source already answers it (artifact, project-context, codebase). If yes, surface the answer and confirm: "I see X is already decided as Y in {source}. Confirming we keep that?" Wait for yes/no.
2. If no source answers it, ask a single question with a recommended answer:
   ```
   Q{n} of ~{budget}. Decision: {what we need to settle}
   Recommendation: {your recommended answer}
   Why: {one line of reasoning}

   Going with this, or different?
   ```
   `{n}` is the count of questions actually asked so far (confirms-from-source don't increment it). `{budget}` is the unresolved-node count from Step 1, recomputed if the tree changes. The budget is approximate; signal that with the `~`.
3. Wait for response. Record the resolution.
4. Surface dependencies the resolution unlocks: "Settling on {answer} means next we need to decide {dependent_decision}."
5. Move to the next unresolved node.

### Step 3: Loop Detection

If the user circles back and changes a parent decision after children were already resolved, restart traversal from that parent and re-examine the children. State explicitly: "Changing {parent} means we should revisit {children}."

### Step 4: Halt Conditions

Stop and return when any of these is true:
- All branches reachable from the root are resolved
- User says "stop", "enough", "that's good", or invokes another skill
- Intensity budget reached (light = 5 questions max)
- A decision requires information the user does not currently have. Record it as a deferred decision with a clear unblock condition, then move on or stop.

### Step 5: Return

When invoked from a calling skill, return a structured summary the caller can append to the artifact:

```markdown
## Grilled Decisions

| Decision | Resolution | Source | Notes |
|---|---|---|---|
| {decision} | {answer} | {grill | artifact | code | project-context} | {one-line rationale} |

## Deferred (Need Info)

- {decision} — blocked on {unblock_condition}
```

When invoked directly by the user, present the same summary as the final output.

## Anti-Patterns

- **Don't list options without a recommendation.** "Which database do you want, Postgres or MySQL?" is wrong. "Recommend Postgres because the existing services in this workspace use it. Going with Postgres, or different?" is right.
- **Don't ask compound questions.** "What database, ORM, and migration strategy do you want?" is three questions. Ask the database, settle it, then ask the ORM.
- **Don't skip dependency surfacing.** When a parent is settled, name the children explicitly. Don't just silently move on.
- **Don't grill on settled ground.** If the artifact already records the answer, confirm it and move on. Re-asking burns the user's patience.
- **Don't keep grilling after the user signals done.** "Looks good", "ship it", "that's enough" all mean stop. Return the summary.

## Example

User invokes from inside `bmad-create-architecture` step 4, topic = "data architecture", intensity = `light` (auto-invoked default). Tree built; 4 critical nodes unresolved → budget = 4.

```
Q1 of ~4. Decision: Database engine.
          Recommendation: PostgreSQL 16. Existing services in this workspace use it,
          and the project-context.md mentions JSON-heavy payloads where Postgres' jsonb
          beats MySQL's json type.
          Going with PostgreSQL 16, or different?

User: yes Postgres
[recorded. Surfaces children: ORM, migration tool, connection pooling]

Q2 of ~4. Decision: ORM / data access layer.
          Recommendation: Drizzle. The existing services in this workspace use it,
          and the team has prior Drizzle experience per the project-context.
          Going with Drizzle, or different?

User: actually let's use Prisma here
[recorded. Loop detection: Prisma changes the migration-tool child. Tree
 recomputed; budget bumps to ~5 because Prisma also adds a connection-pooling
 sub-decision Drizzle wouldn't have surfaced.]

Q3 of ~5. Decision: Migration strategy.
          Recommendation: Prisma Migrate with versioned migration files committed to
          the repo. Standard for Prisma projects.
          Going with Prisma Migrate, or different?

...continues until all critical-tier branches resolved, then returns.
```

## Boundaries

- **Caveman mode compatibility.** If caveman is active, keep questions terse but never drop the recommendation or the reason. Both are load-bearing.
- **Communication language.** Speak in `{communication_language}` per project config.
- **No artifact writing.** This skill returns resolved decisions. The calling skill writes them to the artifact. When invoked directly, present the summary; do not modify files unless the user explicitly requests it.
