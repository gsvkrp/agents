"""Tool functions for the LangChain worked-example agent.

ONE tool (`list_amenities`) is fully implemented as a reference. The rest are
stubs - implement the ones you need.

The functions are plain Python so they're trivial to unit-test. At the bottom
of this file we wrap them with `@tool` from `langchain_core.tools` to produce
the `AGENT_TOOLS` list that `agent.py` passes to `create_agent(tools=...)`.
LangChain derives each tool's JSON schema from the type hints + docstring, so:

  - Use precise type hints (`Optional[int]`, `bool`, ...).
  - Write a clear docstring describing what the tool does and when to call it.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from langchain_core.tools import tool

from frameworks._shared.data_io import load_json  # also: append_json_item, write_json


# ---------- Worked example ----------------------------------------------------

def list_amenities() -> List[str]:
    """List the amenities available at the property."""
    return load_json("property_info.json").get("amenities", [])


# ---------- Stubs - implement what you need -----------------------------------

def get_open_balance(resident_id: str) -> Dict[str, Any]:
    """Return the open balance for a resident (use residents.json)."""
    raise NotImplementedError


def get_next_month_rent(resident_id: str) -> Dict[str, Any]:
    """Return next month's rent for a resident."""
    raise NotImplementedError


def list_rent_payments(resident_id: str, year: Optional[int] = None) -> List[Dict[str, Any]]:
    """List a resident's rent payments, optionally filtered by year."""
    raise NotImplementedError


def get_office_hours(day: Optional[str] = None) -> Dict[str, Any]:
    """Return office hours, optionally for a specific weekday like 'saturday'."""
    raise NotImplementedError


def list_community_rules() -> List[str]:
    """List the community rules."""
    raise NotImplementedError


def list_upcoming_events(month: Optional[int] = None) -> List[Dict[str, Any]]:
    """List upcoming events, optionally filtered by month (1-12)."""
    raise NotImplementedError


def list_event_signups(resident_id: str) -> List[Dict[str, Any]]:
    """List a resident's event signups."""
    raise NotImplementedError


def sign_up_for_event(resident_id: str, event_id: str, guests: int = 0) -> Dict[str, Any]:
    """Append a new signup to event_signups.json and return it."""
    raise NotImplementedError


def list_maintenance_requests(resident_id: str) -> List[Dict[str, Any]]:
    """List maintenance requests filed by a resident."""
    raise NotImplementedError


def create_maintenance_request(
    resident_id: str, description: str, priority: str = "Medium"
) -> Dict[str, Any]:
    """Append a new maintenance request and return it."""
    raise NotImplementedError


def list_packages(resident_id: str, only_available: bool = True) -> List[Dict[str, Any]]:
    """List packages for a resident; by default only those still available."""
    raise NotImplementedError


# ---------- Tools registered with the agent ---------------------------------
# Wrap each plain Python function above with `tool(...)` and add it here.

AGENT_TOOLS = [
    tool(list_amenities),
    # TODO: add more wrapped tools, e.g.
    #   tool(get_open_balance),
    #   tool(sign_up_for_event),
]
