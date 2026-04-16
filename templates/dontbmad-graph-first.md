# BMad Graph-First — Prefer the Knowledge Graph Over Reading Full Source

When a codebase knowledge graph exists (`graphify-out/graph.json`), use it as the primary navigation tool before falling back to reading source files directly. The graph is faster, gives you structural context, and avoids wasting tokens on irrelevant code.

## When the Graph Exists

Before opening source files to answer a structural question (dependencies, call chains, module roles, blast radius), check whether `graphify-out/graph.json` exists. If it does:

1. **Start with GRAPH_REPORT.md** — `graphify-out/GRAPH_REPORT.md` contains god nodes, community clusters, and surprising connections. Skim this first to orient yourself.

2. **Query before reading** — Use graphify commands instead of grepping or reading entire files:

   | You need to know... | Use this |
   |---|---|
   | What depends on X, what X uses | `uvx --from graphifyy graphify query "what depends on X?"` |
   | What a specific symbol does and connects to | `uvx --from graphifyy graphify explain "SymbolName"` |
   | How two symbols are connected | `uvx --from graphifyy graphify path "A" "B"` |
   | Entry points, architecture overview | `uvx --from graphifyy graphify query "what are the main entry points?"` |

3. **Read only what you need** — After the graph narrows down the relevant files and symbols, read those specific locations rather than scanning entire directories.

## When to Skip the Graph

- The graph doesn't exist (`graphify-out/` is missing) — fall back to normal file reads. Don't error or complain.
- The user is asking about file content that isn't structural (config values, string literals, comments).
- You need the exact current implementation, not just the dependency picture.

## When to Rebuild

If you notice the graph is stale (references symbols that no longer exist, missing recently added modules), tell the user:

> The knowledge graph may be out of date. Run `/dontbmad-graphify` to rebuild it.

Do not rebuild automatically.

## Why This Matters

Reading full source files to understand structure is expensive and slow. A single `graphify query` returns the dependency picture in seconds with a fraction of the tokens. Use the graph as your map; read source only when you need the territory.
