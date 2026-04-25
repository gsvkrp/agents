# LangGraph Skeleton

Minimal scaffold built on a custom `StateGraph` (LangGraph 1.x). The worked
example wires `agent` and `tools` nodes with `tools_condition` so you can see
the graph and extend it (add nodes, branches, persistence, HITL).

## Files
- `tools.py`: Plain Python tool functions + `@tool` registration.
- `graph.py`: `StateGraph` builder and `run_graph(prompt)` entry point.
- `main.py`: Typer CLI entry point (delegates to `frameworks._shared.cli`).

Shared helpers (env, data dir, JSON I/O, REPL) live in `frameworks/_shared/`.

## Run
```bash
uv run python -m frameworks.langgraph.main --prompt "Sign me up for event E003."
```

## Next steps
- Implement the tool stubs in `tools.py`.
- Optionally extend the graph: add a router node, conditional edges, or a
  `MemorySaver` checkpointer.
