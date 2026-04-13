# Graphify — Build Codebase Knowledge Graph

Build the knowledge graph from code, docs, and design artifacts. Use when the user says "build the graph", "graphify", "update the knowledge graph", or at sprint start to give all BMAD workflows structural codebase awareness.

## What This Does

[Graphify](https://github.com/safishamsi/graphify) reads your codebase and produces:

- `graphify-out/GRAPH_REPORT.md` — god nodes, communities, surprising connections
- `graphify-out/graph.json` — queryable graph (nodes, edges, relationships)

BMAD workflows (`dev-story`, `quick-dev`, `code-review`, `create-story`, `create-architecture`) automatically read the graph report when it exists. No extra steps during development.

## Running Graphify

This project uses `uv` (not system pip). Always invoke via `uvx`:

```bash
uvx --from graphifyy graphify <command>
```

### Build / rebuild the graph

```bash
uvx --from graphifyy graphify update .
```

This extracts code structure via AST parsing (no LLM needed). Results are cached — re-runs only process changed files. Output goes to `graphify-out/`.

### Install always-on rule (one time per project)

For Cursor:
```bash
uvx --from graphifyy graphify cursor install
```

For Claude Code:
```bash
uvx --from graphifyy graphify claude install
```

### When to rebuild

| Trigger | Action |
|---|---|
| Sprint start | Full rebuild: `graphify update .` |
| Added new docs, specs, or design artifacts | Full rebuild: `graphify update .` |
| Day-to-day development | No rebuild needed. Workflows read the existing graph. |
| Major refactor (new modules, renamed files) | Full rebuild: `graphify update .` |

### Other commands

| Command | What it does |
|---|---|
| `graphify query "<question>"` | BFS traversal of graph.json for a question |
| `graphify explain "<node>"` | Plain-language explanation of a node and its neighbors |
| `graphify path "<A>" "<B>"` | Shortest path between two nodes |
| `graphify cluster-only .` | Rerun clustering on existing graph.json, regenerate report |
| `graphify watch .` | Watch folder and rebuild on code changes |

See the `bmad-graphify-query`, `bmad-graphify-explain`, and `bmad-graphify-path` skills for detailed usage of those commands.

## How BMAD Workflows Use It

| Workflow | What it reads | Why |
|---|---|---|
| `dev-story` | GRAPH_REPORT.md + graph.json | Navigate to relevant files, trace callers/callees before modifying functions |
| `quick-dev` | GRAPH_REPORT.md + graph.json | Find relevant modules during investigation, avoid grepping blind |
| `code-review` | GRAPH_REPORT.md | Understand blast radius — which modules depend on changed files |
| `create-story` | GRAPH_REPORT.md + graph.json | Write accurate Dev Notes with real file paths and dependencies |
| `create-architecture` | GRAPH_REPORT.md | Ground truth of existing codebase structure for brownfield projects |

If `graphify-out/` doesn't exist, all workflows skip the graph step gracefully. Nothing breaks.
