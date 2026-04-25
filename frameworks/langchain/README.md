# LangChain Skeleton

Minimal scaffold with no LLM calls, intended to show where to add your logic.

## Files
- `tools.py`: Plain Python tool functions + `@tool` registration.
- `agent.py`: Builds the `create_agent` runner and exposes `run_agent(prompt)`.
- `main.py`: Typer CLI entry point (delegates to `frameworks._shared.cli`).

Shared helpers (env, data dir, JSON I/O, REPL) live in `frameworks/_shared/`.

## Run
```bash
uv run python -m frameworks.langchain.main --prompt "List the amenities."
```

## Next steps
- Implement tools in `tools.py` using `frameworks._shared.data_io`.
- Wrap each new tool with `tool(...)` in the `AGENT_TOOLS` list.
