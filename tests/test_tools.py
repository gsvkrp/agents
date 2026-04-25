"""Offline smoke tests for tool functions across all four frameworks.

These tests do NOT call OpenAI. They invoke the plain Python tool functions in
each framework's `tools.py` directly. The framework wrapping (`function_tool`,
`@tool`, `BaseTool`) is applied separately when the agent is built, so these
tests stay framework-agnostic.

Set TEST_FRAMEWORK to limit testing to one framework, e.g.

    TEST_FRAMEWORK=agents_sdk pytest -q

Otherwise all four are tested. Tests for unimplemented tools are skipped, so
you get a green run as soon as the tools you have written are correct.
"""
from __future__ import annotations

import importlib
import os

import pytest


_ALL = ["agents_sdk", "langchain", "langgraph", "crewai"]
FRAMEWORKS = [os.environ["TEST_FRAMEWORK"]] if os.environ.get("TEST_FRAMEWORK") else _ALL


@pytest.fixture(params=FRAMEWORKS)
def tools(request):
    return importlib.import_module(f"frameworks.{request.param}.tools")


def _maybe(fn, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except NotImplementedError:
        pytest.skip(f"{fn.__name__} not implemented yet")


def test_list_amenities_returns_known_items(tools):
    result = tools.list_amenities()
    assert isinstance(result, list) and result, "expected a non-empty list"
    assert "Gym" in result


def test_get_open_balance_for_known_resident(tools):
    result = _maybe(tools.get_open_balance, "R001")
    assert isinstance(result, dict)
    assert result.get("open_balance") == 82646
    assert result.get("currency") == "INR"


def test_get_open_balance_unknown_resident_does_not_crash(tools):
    result = _maybe(tools.get_open_balance, "R999")
    assert result is None or isinstance(result, dict)


def test_list_upcoming_events_filter_by_month(tools):
    result = _maybe(tools.list_upcoming_events, month=11)
    assert isinstance(result, list)
    assert all("start_at" in e for e in result)
    assert any(e["start_at"].startswith("2025-11") for e in result)


def test_list_packages_default_only_available(tools):
    result = _maybe(tools.list_packages, "R002")
    assert isinstance(result, list)
    assert all(p.get("status") == "Available" for p in result)


def test_sign_up_for_event_appends(tools, tmp_path, monkeypatch):
    import json
    from pathlib import Path

    from frameworks._shared import config

    src = Path(config.DATA_DIR)
    for name in ("residents.json", "event_signups.json", "property_info.json"):
        (tmp_path / name).write_text((src / name).read_text())
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)

    before = json.loads((tmp_path / "event_signups.json").read_text())
    _maybe(tools.sign_up_for_event, "R001", "E003")
    after = json.loads((tmp_path / "event_signups.json").read_text())
    assert len(after) == len(before) + 1
    assert after[-1]["resident_id"] == "R001"
    assert after[-1]["event_id"] == "E003"
