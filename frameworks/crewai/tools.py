"""Tool functions for the CrewAI worked-example agent.

ONE tool (`list_amenities`) is fully implemented as a reference. The rest are
stubs - implement the ones you need.

CrewAI tools are class-based (`crewai.tools.BaseTool`). To keep the actual
data-access logic easy to unit-test, we follow this two-layer pattern:

  1. A plain Python function with the real logic (e.g. `list_amenities`).
  2. A `BaseTool` subclass whose `_run` delegates to the function and whose
     `args_schema` (Pydantic) describes the tool's inputs to the LLM.

`AGENT_TOOLS` at the bottom is the list of `BaseTool` instances passed to the
Agent in `crew.py`.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Type

from crewai.tools import BaseTool
from pydantic import BaseModel, Field

from frameworks._shared.data_io import load_json  # also: append_json_item, write_json


# ---------- Plain Python functions -------------------------------------------

def list_amenities() -> List[str]:
    """List the amenities available at the property."""
    return load_json("property_info.json").get("amenities", [])


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


# ---------- BaseTool wrappers -----------------------------------------------

class ListAmenitiesTool(BaseTool):
    name: str = "list_amenities"
    description: str = "List the amenities available at the property."

    def _run(self) -> List[str]:
        return list_amenities()


# Example template for a stub once you implement it:
#
#   class GetOpenBalanceArgs(BaseModel):
#       resident_id: str = Field(description="Resident ID like 'R001'.")
#
#   class GetOpenBalanceTool(BaseTool):
#       name: str = "get_open_balance"
#       description: str = "Return the open balance for a resident."
#       args_schema: Type[BaseModel] = GetOpenBalanceArgs
#
#       def _run(self, resident_id: str) -> Dict[str, Any]:
#           return get_open_balance(resident_id)


AGENT_TOOLS = [
    ListAmenitiesTool(),
    # TODO: add more BaseTool instances.
]
