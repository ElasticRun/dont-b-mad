# Graphify Explain — Understand a Node's Role

Get a plain-language explanation of any node in the knowledge graph and its neighbors. Use when the user says "explain node", "what is this function", "what does X connect to", or wants to understand a specific symbol's role in the codebase.

## Prerequisites

Graph must already be built (`graphify-out/graph.json` must exist). If not, run `bmad-graphify` first.

## Usage

```bash
uvx --from graphifyy graphify explain "<node_name>"
```

### Options

| Flag | Description |
|---|---|
| `--graph <path>` | Path to graph.json (default `graphify-out/graph.json`) |

### Finding node names

Node names come from the graph. Check `graphify-out/GRAPH_REPORT.md` for the god nodes list and community members, or run a query first to discover node labels.

### Examples

```bash
# Explain a core function
uvx --from graphifyy graphify explain "request"

# Explain a component
uvx --from graphifyy graphify explain "AuthGuard"

# Explain a utility
uvx --from graphifyy graphify explain "convertKeys"

# Explain a class
uvx --from graphifyy graphify explain "GitLabApiError"
```

### When to use

- Before modifying a function — understand what depends on it
- During code review — quickly grasp a symbol's role without reading source
- Story creation — gather context about modules referenced in the story
