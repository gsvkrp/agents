"""JSON read/write helpers used by every framework's tools."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from . import config


def _path(file_name: str) -> Path:
    # Resolve via the module attribute so tests can monkeypatch DATA_DIR.
    return config.DATA_DIR / file_name


def load_json(file_name: str) -> Any:
    """Load JSON from `tools_data/`. Returns `[]` if the file is missing."""
    path = _path(file_name)
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(file_name: str, data: Any) -> None:
    """Overwrite a JSON file under `tools_data/`."""
    path = _path(file_name)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def append_json_item(file_name: str, item: dict) -> None:
    """Append an object to a list-backed JSON file under `tools_data/`."""
    current = load_json(file_name)
    if not isinstance(current, list):
        raise ValueError(f"{file_name} is not a list-backed JSON file")
    current.append(item)
    write_json(file_name, current)
