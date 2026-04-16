---
name: dontbmad-compress-artifacts
description: >
  Compress BMAD planning artifacts (PRDs, architecture docs, stories, project-context) into
  terse format to reduce input tokens when agents read them. Originals backed up as .original.md.
  Use when user says "compress artifacts", "compress planning docs", or "shrink the docs".
---

# Compress BMAD Artifacts

Compress planning artifact markdown files into terse caveman format so agents load fewer input tokens in future sessions. Human-readable originals are backed up as `<filename>.original.md`.

## When to Use

- After generating multiple planning artifacts (PRDs, architecture, stories, epics)
- Before a heavy multi-agent session (party mode, dev-story) to reduce context load
- When context window pressure is high and you need to reclaim tokens

## What Gets Compressed

Scan `{planning_artifacts}/` (resolved from `{project-root}/_bmad/bmm/config.yaml`) for `.md` files. Also check for `**/project-context.md`.

**Compress:** Prose sections in markdown files — descriptions, rationale, notes, acceptance criteria written in sentences.

**Never compress:**
- Files already ending in `.original.md` (skip — these are backups)
- Code blocks (fenced ``` and indented)
- Inline code (`backtick content`)
- URLs, file paths, commands
- Technical terms, proper nouns, version numbers
- YAML frontmatter
- Table structure (compress cell text, keep structure)
- Mermaid diagrams

## Process

For each `.md` file found:

1. Check if `<filename>.original.md` already exists. If yes, skip (already compressed).
2. Copy the current file to `<filename>.original.md` as human-readable backup.
3. Rewrite the original file in place using caveman compression rules:
   - Remove articles (a/an/the), filler, hedging, pleasantries
   - Use fragments and short synonyms
   - Merge redundant bullets that say the same thing differently
   - Keep one example where multiple examples show the same pattern
   - Preserve all markdown structure (headings, bullets, numbering, tables)
   - Preserve all code blocks and inline code exactly
4. Report: filename, original token count (approx), compressed token count, savings percentage.

## Compression Rules

### Remove
- Articles: a, an, the
- Filler: just, really, basically, actually, simply, essentially, generally
- Pleasantries: "sure", "certainly", "of course"
- Hedging: "it might be worth", "you could consider", "it would be good to"
- Redundant phrasing: "in order to" -> "to", "make sure to" -> "ensure", "the reason is because" -> "because"
- Connective fluff: "however", "furthermore", "additionally"

### Preserve Exactly
- Code blocks (fenced and indented)
- Inline code
- URLs and markdown links
- File paths and commands
- Technical terms, library names, API names
- Proper nouns, dates, version numbers
- Environment variables

### Compress
- Short synonyms: "big" not "extensive", "fix" not "implement a solution for", "use" not "utilize"
- Fragments OK: "Run tests before commit" not "You should always run tests before committing"
- Drop "you should", "make sure to", "remember to" — state the action directly

## Example

**Before:**
> The application should provide users with the ability to search for available delivery slots in their area. The system must validate that the selected time slot is still available before confirming the booking.

**After:**
> Users search available delivery slots by area. System validate slot availability before booking confirmation.

## Restore

To restore a file to its original version:
```bash
mv <filename>.original.md <filename>.md
```

## Output

After compression, print a summary table:

| File | Before | After | Saved |
|---|---|---|---|
| prd.md | ~2400 tokens | ~1300 tokens | 46% |
| architecture.md | ~3100 tokens | ~1700 tokens | 45% |
| **Total** | **~5500** | **~3000** | **~45%** |
