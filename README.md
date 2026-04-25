# Resident Assistant — Coding Exercise

Welcome! In this exercise you will build a chat-based agent that answers
resident questions and performs actions against JSON-backed data.

## Quick start (in Codespaces)

This repo ships with a dev container, so when you open it in **GitHub
Codespaces** you get a ready-to-go VS Code environment in your browser:

1. Click **Code → Codespaces → Create codespace on main**.
2. Wait for the post-create step to finish (`uv sync` provisions `.venv/`).
3. The `OPENAI_API_KEY` is already injected into the environment as a Codespaces
   secret — you do **not** need to create a `.env` file.
4. Try the worked example, then start coding:
   ```bash
   make test                                     # offline tool tests, no API
   make run                                      # one prompt, default = "List the amenities."
   make run PROMPT="What's my open balance?"     # any prompt
   make repl                                     # interactive REPL
   ```

> Local setup (optional): install [`uv`](https://docs.astral.sh/uv/), then
> `uv sync`, `cp .env.example .env`, and add your `OPENAI_API_KEY`.

## Start here: four worked examples (one per framework)

To save you the boilerplate, **all four framework folders are wired end-to-end
with one working tool (`list_amenities`)** using each framework's own modern
primitives — not a lowest-common-denominator OpenAI loop. Pick one, run it,
then add tools.

| Framework  | Idiom used in the worked example                              | Files |
|------------|----------------------------------------------------------------|-------|
| Agents SDK | `Agent`, `Runner.run_sync`, `function_tool(...)`               | [`agents_sdk/agent.py`](frameworks/agents_sdk/agent.py), [`agents_sdk/tools.py`](frameworks/agents_sdk/tools.py) |
| LangChain  | `langchain.agents.create_agent` (v1), `@tool` from `langchain_core` | [`langchain/agent.py`](frameworks/langchain/agent.py), [`langchain/tools.py`](frameworks/langchain/tools.py) |
| LangGraph  | Custom `StateGraph` + `ToolNode` + `tools_condition` (LangGraph 1.x)  | [`langgraph/graph.py`](frameworks/langgraph/graph.py), [`langgraph/tools.py`](frameworks/langgraph/tools.py) |
| CrewAI     | `Agent` + `Task` + `Crew`, tools as `BaseTool` subclasses       | [`crewai/crew.py`](frameworks/crewai/crew.py), [`crewai/tools.py`](frameworks/crewai/tools.py) |

Run any of them once to confirm everything works:

```bash
make run                                      # default: agents_sdk + "List the amenities."
make run FRAMEWORK=langchain
make run FRAMEWORK=langgraph
make run FRAMEWORK=crewai
```

Then **pick one framework** and add tools to its `tools.py`. The runner files
do not need to change — adding a tool is a one-line registration.

> If you want to demo deeper framework knowledge, you're welcome to extend the
> worked example — e.g. add nodes to the LangGraph `StateGraph`, build a
> multi-agent `Crew`, or add handoffs in the Agents SDK. Use the worked example
> as a starting point, not a ceiling.

## Your task

Build a chat-based assistant that:

- Accepts natural language queries from a resident (e.g. "What's my balance?").
- Uses tools/functions to read and write the JSON files under `tools_data/`.
- Treats the env var `RESIDENT_ID` (defaults to `R001`) as "the current user"
  so questions like "what's my balance?" work without the user typing an ID.

### Sample queries you should be able to answer

**Rent & balance**
- "What's my open balance?"
- "How much is next month's rent?"
- "Show me my rent payments for this year."

**Property info**
- "What are the office hours on Saturday?"
- "List the amenities available."
- "What are the community rules?"

**Events**
- "What events are coming up?"
- "Show me events in November."
- "List my event signups."
- "Sign me up for event E003."

**Maintenance & packages**
- "List my maintenance requests."
- "Do I have any packages to collect?"

You don't need to support every query — pick a focused subset and make it work
well end-to-end.

## Pick one framework

Four skeletons are provided. **Pick one** and implement it; ignore the others.
Each one already has a working `list_amenities` tool wired with that
framework's own primitives (see the table at the top).

| Framework  | Where the runner lives                       | Where tools live                    |
|------------|----------------------------------------------|-------------------------------------|
| Agents SDK | `frameworks/agents_sdk/agent.py`             | `frameworks/agents_sdk/tools.py`    |
| LangChain  | `frameworks/langchain/agent.py`              | `frameworks/langchain/tools.py`     |
| LangGraph  | `frameworks/langgraph/graph.py`              | `frameworks/langgraph/tools.py`     |
| CrewAI     | `frameworks/crewai/crew.py`                  | `frameworks/crewai/tools.py`        |

Each framework folder contains only its idiomatic pieces:

- `tools.py` — plain Python functions + framework-specific tool wrapping.
- `agent.py` / `graph.py` / `crew.py` — the framework runner.
- `main.py` — a thin Typer CLI built from `frameworks._shared.cli.make_cli`.

Shared helpers used by every framework live in `frameworks/_shared/`:

- `config.py` — loads env vars, exposes `MODEL`, `DATA_DIR`, `data_path`,
  `resident_id`, and the canonical `system_prompt()`.
- `data_io.py` — `load_json`, `write_json`, `append_json_item`.
- `cli.py` — `make_cli(run_fn, label)` Typer factory used by every `main.py`.

## Fast feedback (no tokens spent)

`tests/test_tools.py` calls your tool functions directly without hitting OpenAI.
Tests for unimplemented tools are skipped, so you get a green run as soon as
the tools you've written are correct.

```bash
make test
```

Use this loop while building. Then run a live prompt occasionally to confirm
the LLM picks the right tool and formats a sensible reply.

## Running

```bash
# Single prompt
uv run python -m frameworks.agents_sdk.main --prompt "List the amenities."

# Interactive REPL
uv run python -m frameworks.agents_sdk.main
```

(Substitute `agents_sdk` with `langchain`, `langgraph`, or `crewai` for the
other skeletons.)

## Data files

All under `tools_data/`:

- `residents.json` — resident info, rent, balance, payments, ledger charges
- `maintenance_requests.json` — service requests
- `property_info.json` — office hours, amenities, rules, upcoming events
- `event_signups.json` — resident event registrations
- `packages.json` — package availability per resident

Resident IDs are `R001` .. `R012`.

## What we're looking for

- A working agent in the framework you chose, using **that framework's
  idioms** (Agents SDK `Agent`/`Runner`, LangChain `AgentExecutor`, LangGraph
  `StateGraph`, CrewAI `Crew` — not a hand-rolled OpenAI loop in disguise).
- **Good tool design**: small, focused inputs/outputs; pre-filter server-side
  rather than dumping whole JSON files back to the model.
- **Clear schemas/descriptions** the LLM can actually use (with the Agents SDK
  this means good type hints + docstrings; other frameworks have their own
  conventions).
- Sensible handling of unknown residents / events.
- At least one **write** tool exercised (signup or maintenance request).
- Brief notes (in your code or a short comment) on **why** you picked that
  framework — and one trade-off you noticed.

Good luck!
