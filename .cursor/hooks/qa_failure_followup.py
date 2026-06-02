#!/usr/bin/env python3
"""Stop hook: auto-continue when a QA gate failure is pending for this conversation."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from qa_failure_state import conversation_key, get_failure


def main() -> None:
    raw = sys.stdin.read()
    if not raw.strip():
        sys.stdout.write("{}")
        return

    data = json.loads(raw)
    if data.get("status") != "completed":
        sys.stdout.write("{}")
        return

    pending = get_failure(conversation_key(data))
    if not pending:
        sys.stdout.write("{}")
        return

    command = pending.get("command", "mise exec -- bin/ci")
    spec_paths = pending.get("spec_paths") or []
    paths_text = ", ".join(spec_paths[:5]) if spec_paths else "see prior [qa-hook] output"

    followup = (
        "[qa-hook auto-continue] A quality gate command failed in this session. "
        f"Fix the root cause and re-run to verify: {command}. "
        f"Failing location(s): {paths_text}. "
        "Follow context/foundation/test-plan.md §6.7 and AGENTS.md security rules."
    )
    sys.stdout.write(json.dumps({"followup_message": followup}))


if __name__ == "__main__":
    main()
