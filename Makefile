# Convenience targets driven by uv. Run `make help` to list them.

FRAMEWORK ?= agents_sdk
PROMPT ?= List the amenities.

.PHONY: help install sync test run repl clean

help:
	@echo "make install              Create venv and install all deps (uv sync)"
	@echo "make test                 Run offline tool tests (no OpenAI calls)"
	@echo "make run [PROMPT=...]     Run one prompt through the agent"
	@echo "make repl                 Start the interactive REPL"
	@echo ""
	@echo "Override the framework with FRAMEWORK=langchain | langgraph | crewai"

install sync:
	uv sync

test:
	uv run pytest

run:
	uv run python -m frameworks.$(FRAMEWORK).main --prompt "$(PROMPT)"

repl:
	uv run python -m frameworks.$(FRAMEWORK).main

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	rm -rf .pytest_cache .venv
