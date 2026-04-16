# Graphify Path — Trace Connections Between Nodes

Find the shortest path between two nodes in the knowledge graph. Use when the user says "trace path", "how are these connected", "path between", or wants to understand how two symbols relate through the codebase.

## Prerequisites

Graph must already be built (`graphify-out/graph.json` must exist). If not, run `dontbmad-graphify` first.

## Usage

```bash
uvx --from graphifyy graphify path "<node_A>" "<node_B>"
```

### Options

| Flag | Description |
|---|---|
| `--graph <path>` | Path to graph.json (default `graphify-out/graph.json`) |

### Finding node names

Node names come from the graph. Check `graphify-out/GRAPH_REPORT.md` for the god nodes list and community members, or run a query first to discover node labels.

### Examples

```bash
# Trace how a UI component reaches the API layer
uvx --from graphifyy graphify path "AuthGuard" "request"

# Understand the call chain between two functions
uvx --from graphifyy graphify path "gitlabGet" "convertKeys"

# Find how an error class connects to a handler
uvx --from graphifyy graphify path "GitLabApiError" "handleAddByUrl"
```

### When to use

- Impact analysis — trace how a change in module A could ripple to module B
- Debugging — find the call chain between a failing test and the root cause
- Architecture review — verify expected vs actual dependency paths
- Story planning — understand coupling between components before splitting work
