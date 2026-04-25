# Agents SDK (OpenAI Python SDK) Skeleton

This is a minimal scaffold intended to demonstrate file layout and where to add your logic. No LLM calls are made.

## Files
- `tools.py`: Plain Python tool functions + `function_tool(...)` registration.
- `agent.py`: Builds the `Agent` and exposes `run_agent(prompt)`.
- `main.py`: Typer CLI entry point (delegates to `frameworks._shared.cli`).

Shared helpers (env, data dir, JSON I/O, REPL) live in `frameworks/_shared/`.

## Run
```bash
uv run python -m frameworks.agents_sdk.main --prompt "What’s my balance?"
```

## Next steps
- Implement tools in `tools.py` using `frameworks._shared.data_io`.
- Wrap each new tool with `function_tool(...)` in the `AGENT_TOOLS` list.
