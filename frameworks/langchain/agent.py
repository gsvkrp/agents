"""LangChain - WORKED EXAMPLE.

Uses LangChain v1's modern primitives:
  - `@tool` from `langchain_core.tools` (in `tools.py`) for tool declaration.
  - `langchain.agents.create_agent(...)` to build a tool-calling agent on top
    of a chat model. (Replaces the deprecated `AgentExecutor` /
    `create_tool_calling_agent` pair from older LangChain.)
"""
from __future__ import annotations

from langchain.agents import create_agent
from langchain_core.messages import HumanMessage

from frameworks._shared.config import MODEL, system_prompt

from .tools import AGENT_TOOLS


def _build_agent():
    return create_agent(
        model=f"openai:{MODEL}",
        tools=AGENT_TOOLS,
        system_prompt=system_prompt(),
    )


def run_agent(prompt: str) -> str:
    agent = _build_agent()
    result = agent.invoke({"messages": [HumanMessage(content=prompt)]})
    final = result["messages"][-1]
    return getattr(final, "content", str(final))
