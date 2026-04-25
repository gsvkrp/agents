"""CrewAI - WORKED EXAMPLE.

Uses CrewAI's modern primitives:
  - `Agent` (a role-based agent with goals, backstory, and tools).
  - `Task` (a single instruction the agent should fulfil).
  - `Crew` (orchestrates one or more agents and tasks).
  - `BaseTool` subclasses for tools (declared in `tools.py`).

For a single-agent property assistant, one Agent + one Task per user prompt is
the simplest shape. To demo multi-agent orchestration, add more Agents/Tasks.
"""
from __future__ import annotations

from crewai import Agent, Crew, Task

from frameworks._shared.config import MODEL, resident_id

from .tools import AGENT_TOOLS


def _build_agent() -> Agent:
    rid = resident_id()
    return Agent(
        role="Resident Assistant",
        goal=(
            "Answer resident questions and perform property-management actions "
            f"on behalf of resident '{rid}' using the provided tools."
        ),
        backstory=(
            "You work for Lakeview Heights. You are concise, helpful, and "
            "always include currency when reporting amounts."
        ),
        tools=AGENT_TOOLS,
        llm=f"openai/{MODEL}",
        allow_delegation=False,
        verbose=False,
    )


def run_crew(prompt: str) -> str:
    agent = _build_agent()
    task = Task(
        description=prompt,
        expected_output="A concise natural-language reply for the resident.",
        agent=agent,
    )
    crew = Crew(agents=[agent], tasks=[task], verbose=False)
    result = crew.kickoff()
    return getattr(result, "raw", str(result))
