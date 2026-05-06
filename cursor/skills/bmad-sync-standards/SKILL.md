---
name: bmad-sync-standards
description: >
  Sync engineering standards from a central catalog into the current project's
  docs/standards/ folder, based on the project's engineering-standards.yml manifest.
  Also generates .cursor/rules/*.mdc and updates CLAUDE.md @imports for editor parity.
  Use when user says "sync standards", "pull standards", "update standards", or
  after editing engineering-standards.yml.
---

# Sync Engineering Standards

Pull a project-specific subset of the central engineering-standards catalog into the project. BMAD skills (create-architecture, create-story, dev-story, code-review) read these from `docs/standards/` and treat constraints as binding.

## When to Use

- New project: after dropping `engineering-standards.yml` at root.
- Updated manifest: added/removed a domain.
- Catalog refresh: standards repo got new docs.
- Onboarding teammate: ensures their checkout has the latest synced standards.

## What This Does

1. Reads `engineering-standards.yml` at project root.
2. Fetches catalog (local path or git URL, per manifest).
3. Copies listed domain folders into `docs/standards/<domain>/`.
4. Writes `docs/standards/INDEX.md` listing what's synced + summaries.
5. Generates `.cursor/rules/<domain>.mdc` for each domain (Cursor parity).
6. Adds `@docs/standards/INDEX.md` to `CLAUDE.md` if not already present.
7. Reports what changed.

## Manifest Format

`engineering-standards.yml` at project root:

```yaml
catalog: /Users/Sachin/Workspace/engineering-standards   # local path OR git URL
version: main                                            # branch/tag/commit (git only)
standards:
  - frappe
  - python-backend
  - redis
  - elasticrun-design
```

If `catalog` starts with `http://`, `https://`, or `git@`, treat as git URL → clone shallow into `.standards-cache/` (gitignored). Otherwise treat as local filesystem path → copy directly.

## Process

### 1. Validate manifest

- Ensure `engineering-standards.yml` exists at project root. If not, halt with: "No `engineering-standards.yml` found. Create one at project root listing the catalog and the domains this project uses."
- Parse YAML. Validate keys: `catalog` (required), `standards` (required, list), `version` (optional).

### 2. Fetch catalog

**Local path:**
- `cp -r <catalog>/<domain>/ docs/standards/<domain>/` for each listed domain.
- Skip domains not present in catalog. Warn user.

**Git URL:**
- If `.standards-cache/` doesn't exist: `git clone --depth 1 -b <version> <catalog> .standards-cache/`.
- Else: `cd .standards-cache && git fetch && git checkout <version> && git pull`.
- Add `.standards-cache/` to `.gitignore` if missing.
- Then copy domain folders as in local case.

### 3. Refresh `docs/standards/`

- Wipe existing `docs/standards/` first (clean slate, no stale files).
- Copy each domain folder.
- Write `docs/standards/INDEX.md` (template below).

### 4. Generate Cursor rules

For each synced domain, write `.cursor/rules/standards-<domain>.mdc`:

```mdc
---
description: <Domain> engineering standards (synced from central catalog)
globs:
alwaysApply: true
---

<concatenated content of all .md files in docs/standards/<domain>/>
```

`alwaysApply: true` ensures Cursor loads them on every chat.

### 5. Update CLAUDE.md

- If `CLAUDE.md` doesn't exist at project root: skip (don't create one).
- If exists: check for `@docs/standards/INDEX.md`. If missing, append a section:

```markdown

## Engineering Standards

@docs/standards/INDEX.md

These rules are binding for all generated code.
```

### 6. Report

Print a table to user:

| Domain | Files synced | Source |
|---|---|---|
| frappe | 10 | catalog/frappe/ |
| python-backend | 4 | catalog/python-backend/ |
| ... | ... | ... |

Plus: cursor rules generated, CLAUDE.md updated/skipped.

## INDEX.md Template

```markdown
# Engineering Standards (synced)

Last synced: <ISO date>
Catalog: <catalog path or URL>
Version: <version>

These standards are binding. BMAD skills (create-architecture, create-story, dev-story, code-review) treat constraints in these files as hard requirements unless explicitly overridden in project-context.md.

## Domains

### frappe
- [Mental Model](frappe/mental-model.md)
- [Doctype Patterns](frappe/doctype-patterns.md)
- ... (auto-list all .md files)

### python-backend
- ...

(repeat per domain)

## Override Rules

If a project rule conflicts with a standard, document the override in `project-context.md` under "Standards Overrides" with the reason. Otherwise, standards win.
```

## Rules

- Never edit files inside `docs/standards/` by hand. They get wiped on next sync. Project-specific overrides go in `project-context.md`.
- `.standards-cache/` always gitignored.
- If a listed domain doesn't exist in catalog, warn but don't fail. Skip it.
- Idempotent. Running twice = same result.

## Don't

- Sync without a manifest. No silent defaults.
- Skip cursor rule generation. 70% of team uses Cursor.
- Modify catalog from a project. Catalog is upstream-only.
- Commit `.standards-cache/` to project repo.
