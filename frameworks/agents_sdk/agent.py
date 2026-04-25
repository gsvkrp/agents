"""OpenAI Agents SDK - WORKED EXAMPLE.

Uses the modern Agents SDK primitives:
  - `Agent` owns instructions + tools + model in one object.
  - `Runner.run_sync` runs the tool-calling loop for you.
  - `@function_tool` (in `tools.py`) derives the JSON schema from type hints
    + docstring, so you don't hand-write tool schemas.
"""
from __future__ import annotations

from agents import Agent, Runner

from frameworks._shared.config import MODEL, system_prompt

from .tools import AGENT_TOOLS


def _build_agent() -> Agent:
    return Agent(
        name="Resident Assistant",
        instructions=system_prompt(),
        model=MODEL,
        tools=AGENT_TOOLS,
    )


def run_agent(prompt: str) -> str:
    result = Runner.run_sync(_build_agent(), prompt)
    return result.final_output or ""
