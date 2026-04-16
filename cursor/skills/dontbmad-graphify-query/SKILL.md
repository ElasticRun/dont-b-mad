# Graphify Query — Search the Knowledge Graph

Ask natural-language questions against the codebase knowledge graph. Use when the user says "query the graph", "graph query", "what depends on", "what uses", or asks a structural question about the codebase.

## Prerequisites

Graph must already be built (`graphify-out/graph.json` must exist). If not, run `dontbmad-graphify` first.

## Usage

```bash
uvx --from graphifyy graphify query "<question>"
```

### Options

| Flag | Description |
|---|---|
| `--dfs` | Use depth-first instead of breadth-first traversal |
| `--budget N` | Cap output at N tokens (default 2000) |
| `--graph <path>` | Path to graph.json (default `graphify-out/graph.json`) |

### Examples

```bash
# What depends on a module
uvx --from graphifyy graphify query "what depends on the auth module?"

# How are API calls structured
uvx --from graphifyy graphify query "how does the gitlab client make requests?"

# Find entry points
uvx --from graphifyy graphify query "what are the main entry points?"

# Use DFS for deeper traversal
uvx --from graphifyy graphify query --dfs "what calls request()?"

# Larger budget for complex answers
uvx --from graphifyy graphify query --budget 4000 "describe the project architecture"
```

### Saving results for feedback loop

After a useful query, save the result so future graph builds can learn from it:

```bash
uvx --from graphifyy graphify save-result --question "what depends on auth?" --answer "The auth module is used by..." --nodes AuthGuard useAuth
```
