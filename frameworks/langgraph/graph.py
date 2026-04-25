"""LangGraph - WORKED EXAMPLE.

Builds an explicit `StateGraph` with two nodes:

    [START] -> agent -> tools_condition -> tools -> agent -> [END]
                            \\------------------------> [END]

This is the modern, idiomatic LangGraph shape (replacing the deprecated
`langgraph.prebuilt.create_react_agent`). Showing the graph explicitly is the
whole point of choosing LangGraph over LangChain's `create_agent` - you can
add nodes, branching, persistence, or human-in-the-loop without leaving the
graph.
"""
from __future__ import annotations

from langchain_core.messages import HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import END, START, MessagesState, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition

from frameworks._shared.config import MODEL, system_prompt

from .tools import AGENT_TOOLS


def _build_graph():
    llm = ChatOpenAI(model=MODEL).bind_tools(AGENT_TOOLS)
    system = system_prompt()

    def agent_node(state: MessagesState) -> dict:
        messages = [{"role": "system", "content": system}, *state["messages"]]
        return {"messages": [llm.invoke(messages)]}

    builder = StateGraph(MessagesState)
    builder.add_node("agent", agent_node)
    builder.add_node("tools", ToolNode(AGENT_TOOLS))

    builder.add_edge(START, "agent")
    builder.add_conditional_edges("agent", tools_condition)
    builder.add_edge("tools", "agent")
    # `tools_condition` routes to END automatically when no tool calls remain.

    return builder.compile()


GRAPH = None


def run_graph(prompt: str) -> str:
    global GRAPH
    if GRAPH is None:
        GRAPH = _build_graph()
    result = GRAPH.invoke({"messages": [HumanMessage(content=prompt)]})
    final = result["messages"][-1]
    return getattr(final, "content", str(final))
