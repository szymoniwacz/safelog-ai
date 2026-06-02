"""Shared pending QA failure state for Cursor hooks (per conversation)."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

STATE_DIR = Path(__file__).resolve().parent / "state"
STATE_PATH = STATE_DIR / "pending_failures.json"


def _load() -> dict:
    if not STATE_PATH.exists():
        return {}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


def _save(data: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")


def conversation_key(data: dict) -> str:
    return data.get("conversation_id") or data.get("session_id") or "_default"


def record_failure(
    key: str,
    *,
    command: str,
    spec_paths: list[str],
    context: str,
) -> None:
    state = _load()
    state[key] = {
        "command": command,
        "spec_paths": spec_paths,
        "context": context,
        "recorded_at": datetime.now(timezone.utc).isoformat(),
    }
    _save(state)


def clear_failure(key: str) -> None:
    state = _load()
    if key in state:
        del state[key]
        _save(state)


def get_failure(key: str) -> dict | None:
    return _load().get(key)
