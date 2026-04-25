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
	@echo ""
	@echo "Operator-only (interview admins): make aws-deploy ENV=alpha — see Makefile."

install sync:
	uv sync

test:
	uv run pytest

run:
	uv run python -m frameworks.$(FRAMEWORK).main --prompt "$(PROMPT)"

repl:
	clear
	uv run python -m frameworks.$(FRAMEWORK).main

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	rm -rf .pytest_cache .venv

# ---------------------------------------------------------------------------
# Operator-only (interview administrators). Forwards `make aws-<x>` here to
# `make <x>` inside ec2/. Candidates never run these. See ec2/Makefile.
#   make aws-login  ENV=alpha
#   make aws-deploy ENV=alpha OPENAI_API_KEY=sk-...
# ---------------------------------------------------------------------------

.PHONY: aws-%
aws-%:
	@$(MAKE) -C ec2 $* $(if $(ENV),ENV=$(ENV))

# git push latest code
# make aws-login
# make aws-deploy

# make aws-stop
# make aws-down
# make aws-nuke