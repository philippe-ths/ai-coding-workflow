"""Parse one Claude Code session transcript into a metrics record.

This module is the ONLY place that knows the on-disk transcript format. If Claude
Code changes its JSONL shape, this file is the single point of repair (see
docs/adr/0001). It extracts metrics only -- never prompt or code content.

Ground truth for this parser is real transcripts under ~/.claude/projects/. The
checked-in fixture (observation/fixtures/sample-transcript.jsonl) mirrors that real
shape with chosen values so observation/test_parse.py can assert exact numbers.
"""

import json
import os
from collections import Counter
from datetime import datetime, timezone

# Prefixes that mark a "user"-type entry as a harness injection rather than a
# real human prompt (slash-command wrappers, local-command output, caveats).
_INJECTED_PREFIXES = ("<command-name>", "<command-message>", "<local-command-", "<command-")


def _is_human_text(text):
    if not isinstance(text, str):
        return False
    stripped = text.lstrip()
    if not stripped:
        return False
    return not stripped.startswith(_INJECTED_PREFIXES)


def _parse_ts(value):
    """Parse an ISO-8601 timestamp (handles trailing Z) to an aware datetime, or None."""
    if not isinstance(value, str) or not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def parse_transcript(path):
    """Return a metrics dict for one transcript file, or None if it has no usable entries."""
    session_id = None
    cwd = None
    timestamps = []
    tokens = {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0}
    models = Counter()
    tool_counts = Counter()
    skill_counts = Counter()
    user_turns = 0
    saw_entry = False

    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(entry, dict):
                continue
            saw_entry = True

            if session_id is None and entry.get("sessionId"):
                session_id = entry["sessionId"]
            if cwd is None and isinstance(entry.get("cwd"), str):
                cwd = entry["cwd"]
            ts = _parse_ts(entry.get("timestamp"))
            if ts is not None:
                timestamps.append(ts)

            etype = entry.get("type")
            message = entry.get("message")
            if not isinstance(message, dict):
                message = {}

            if etype == "assistant":
                usage = message.get("usage") or {}
                tokens["input"] += usage.get("input_tokens") or 0
                tokens["output"] += usage.get("output_tokens") or 0
                tokens["cache_read"] += usage.get("cache_read_input_tokens") or 0
                tokens["cache_creation"] += usage.get("cache_creation_input_tokens") or 0
                model = message.get("model")
                if isinstance(model, str) and model and "synthetic" not in model and "<" not in model:
                    models[model] += 1
                for block in message.get("content") or []:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        name = block.get("name") or "?"
                        tool_counts[name] += 1
                        if name == "Skill":
                            skill = (block.get("input") or {}).get("skill")
                            if isinstance(skill, str) and skill:
                                skill_counts[skill] += 1

            elif etype == "user":
                if entry.get("isSidechain"):
                    continue
                content = message.get("content")
                if isinstance(content, str):
                    if _is_human_text(content):
                        user_turns += 1
                elif isinstance(content, list):
                    # A real prompt carries a text block; tool_result blocks do not count.
                    if any(
                        isinstance(b, dict) and b.get("type") == "text" and _is_human_text(b.get("text"))
                        for b in content
                    ):
                        user_turns += 1

    if not saw_entry:
        return None

    started_at = min(timestamps) if timestamps else None
    ended_at = max(timestamps) if timestamps else None
    duration_seconds = None
    if started_at is not None and ended_at is not None:
        duration_seconds = round((ended_at - started_at).total_seconds(), 3)

    if session_id is None:
        session_id = os.path.splitext(os.path.basename(path))[0]

    model = models.most_common(1)[0][0] if models else None
    repo = os.path.basename(cwd.rstrip("/")) if cwd else None

    return {
        "session_id": session_id,
        "repo": repo,
        "cwd": cwd,
        "started_at": started_at.isoformat() if started_at else None,
        "ended_at": ended_at.isoformat() if ended_at else None,
        "duration_seconds": duration_seconds,
        "model": model,
        "tokens": tokens,
        "tool_calls": {"total": sum(tool_counts.values()), "by_tool": dict(tool_counts)},
        "skills": {"total": sum(skill_counts.values()), "by_skill": dict(skill_counts)},
        "user_turns": user_turns,
    }
