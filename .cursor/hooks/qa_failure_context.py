#!/usr/bin/env python3
"""Inject sanitized QA failure context when quality-gate shell commands fail.

Handles Cursor postToolUse (Shell) and afterShellExecution hook events.
See context/foundation/test-plan.md section 6.7 for gate commands.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from qa_failure_state import clear_failure, conversation_key, record_failure

MAX_LINES = 60
MAX_LINE_LEN = 240

QA_COMMAND_RE = re.compile(
    r"(mise exec -- )?"
    r"(bin/ci|bundle exec rspec|bin/rubocop|bin/brakeman|bin/bundler-audit|importmap audit)"
)

SECRET_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
        "[REDACTED_EMAIL]",
    ),
    (re.compile(r"(?i)bearer\s+[A-Za-z0-9._-]+"), "bearer [REDACTED]"),
    (
        re.compile(r"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+"),
        r"\1=[REDACTED]",
    ),
]

SPEC_PATH_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"#\s+(./spec/[^\s:]+(?::\d+)?)"),
    re.compile(r"\brspec\s+(./spec/[^\s]+(?::\d+)?)", re.IGNORECASE),
    re.compile(r"(./spec/[^\s:]+\.rb:\d+)"),
    re.compile(r"(?<![./\w])(spec/[^\s:]+\.rb:\d+)"),
]


def redact_line(line: str) -> str:
    for pattern, replacement in SECRET_PATTERNS:
        line = pattern.sub(replacement, line)
    if len(line) > MAX_LINE_LEN:
        return line[:MAX_LINE_LEN] + "…"
    return line


def extract_spec_paths(text: str) -> list[str]:
    seen: set[str] = set()
    paths: list[str] = []
    for pattern in SPEC_PATH_PATTERNS:
        for match in pattern.findall(text):
            path = match if match.startswith("./") else f"./{match.lstrip('/')}"
            if path not in seen:
                seen.add(path)
                paths.append(path)
    return paths


def looks_like_failure(command: str, output: str, exit_code: int | None = None) -> bool:
    if exit_code is not None:
        return exit_code != 0

    if re.search(r"\d+ examples?, [1-9]\d* failures?", output):
        return True
    if re.search(r"(?:^|\n)\s*Failures?:\s*\n", output):
        return True
    if "Failure/Error:" in output:
        return True
    if re.search(r"\d+ offenses? detected", output):
        return True
    if re.search(r"Security Warnings:\s*[1-9]", output):
        return True
    if "CI failed" in output or "Signoff: CI failed" in output:
        return True
    if "bin/ci" in command and re.search(r"(?:^|\n)(?:Error|ERROR|FATAL):", output):
        return True
    return False


def truncate_output(output: str) -> str:
    lines = output.splitlines()
    tail = lines[-MAX_LINES:] if len(lines) > MAX_LINES else lines
    return "\n".join(redact_line(line) for line in tail)


def build_context(command: str, output: str) -> str:
    spec_paths = extract_spec_paths(output)
    truncated = truncate_output(output)
    parts = [
        "[qa-hook] Quality gate command failed.",
        f"Command: {command}",
    ]
    if spec_paths:
        parts.append("Failing spec file(s):")
        for path in spec_paths[:10]:
            parts.append(f"  - {path}")
    parts.extend(
        [
            "",
            "Truncated, redacted output (fix the failure; follow context/foundation/test-plan.md §6.7):",
            truncated,
            "",
            "Re-run: mise exec -- bin/ci (full) or mise exec -- bundle exec rspec <path> (targeted).",
            "Do not persist or log raw log substrings (AGENTS.md).",
        ]
    )
    return "\n".join(parts)


def emit_context(context: str, data: dict, command: str, output: str) -> bool:
    key = conversation_key(data)
    spec_paths = extract_spec_paths(output)
    record_failure(
        key,
        command=command,
        spec_paths=spec_paths,
        context=context,
    )
    payload = {"additional_context": context, "agent_message": context}
    sys.stdout.write(json.dumps(payload))
    return True


def maybe_clear_success(data: dict, command: str, output: str, exit_code: int | None) -> None:
    if not QA_COMMAND_RE.search(command):
        return
    if looks_like_failure(command, output, exit_code):
        return
    clear_failure(conversation_key(data))


def handle_post_tool_use(data: dict) -> bool:
    if data.get("tool_name") != "Shell":
        return False

    command = (data.get("tool_input") or {}).get("command", "")
    if not QA_COMMAND_RE.search(command):
        return False

    tool_output_raw = data.get("tool_output") or "{}"
    try:
        tool_output = (
            json.loads(tool_output_raw)
            if isinstance(tool_output_raw, str)
            else tool_output_raw
        )
    except json.JSONDecodeError:
        tool_output = {}

    exit_code = tool_output.get("exitCode", tool_output.get("exit_code"))
    stdout = tool_output.get("stdout") or ""
    stderr = tool_output.get("stderr") or ""
    combined = stdout + (f"\n{stderr}" if stderr else "")

    maybe_clear_success(data, command, combined, exit_code)

    if not looks_like_failure(command, combined, exit_code):
        return False

    context = build_context(command, combined)
    return emit_context(context, data, command, combined)


def handle_after_shell_execution(data: dict) -> bool:
    command = data.get("command", "")
    if not QA_COMMAND_RE.search(command):
        return False

    output = data.get("output") or ""
    maybe_clear_success(data, command, output, None)

    if not looks_like_failure(command, output):
        return False

    context = build_context(command, output)
    return emit_context(context, data, command, output)


def main() -> None:
    raw = sys.stdin.read()
    if not raw.strip():
        sys.stdout.write("{}")
        return

    data = json.loads(raw)
    hook_event = data.get("hook_event_name", "")

    emitted = False
    if hook_event == "postToolUse" or data.get("tool_name") == "Shell":
        emitted = handle_post_tool_use(data)
    elif hook_event == "afterShellExecution" or ("output" in data and "command" in data):
        emitted = handle_after_shell_execution(data)

    if not emitted:
        sys.stdout.write("{}")


if __name__ == "__main__":
    main()
