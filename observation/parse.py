"""Parse one Claude Code session transcript into a metrics record.

This module is the ONLY place that knows the on-disk transcript format. If Claude
Code changes its JSONL shape, this file is the single point of repair (see
docs/adr/0001). It extracts metrics only -- never prompt or code content.

Ground truth for this parser is real transcripts under ~/.claude/projects/. The
checked-in fixtures (observation/fixtures/) mirror that real
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


def _add_tokens(acc, usage):
    acc["input"] += usage.get("input_tokens") or 0
    acc["output"] += usage.get("output_tokens") or 0
    acc["cache_read"] += usage.get("cache_read_input_tokens") or 0
    acc["cache_creation"] += usage.get("cache_creation_input_tokens") or 0
    split = usage.get("cache_creation")
    if isinstance(split, dict):
        acc["cache_creation_1h"] += split.get("ephemeral_1h_input_tokens") or 0


def zero_priced_tokens():
    """Token counts as priced: `cache_creation_1h` is the part of `cache_creation` billed
    at the 1-hour cache rate. collect.py drops it from the stored totals."""
    return {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0, "cache_creation_1h": 0}


def _new_branch():
    return {"tokens_by_model": {}, "days": {}, "skills": Counter(), "first": None, "last": None}


def scan_transcript(path):
    """Read one transcript file (main or subagent) and return its raw metrics, or None.

    Claude Code writes one entry per content block of a reply and repeats the reply's
    usage on each, so usage is counted once per message id. In subagent transcripts
    the repeated output count grows as the reply streams, so the last entry's usage is
    the one kept. Each reply's usage is also kept per git branch and per model, so
    collect.py can attribute cost to a task and price each model at its own rate.
    """
    session_id = None
    cwd = None
    timestamps = []
    tokens = zero_priced_tokens()
    tokens_by_model = {}
    models = Counter()
    tool_counts = Counter()
    skill_counts = Counter()
    branches = {}
    agent_calls = {}  # Agent/Task tool_use id -> branch it was launched from
    replies = {}  # message id -> (usage, model, branch, day); the last entry's usage wins
    seen_tool_uses = set()
    user_turns = 0
    saw_entry = False
    branch = None

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
            if isinstance(entry.get("gitBranch"), str) and entry["gitBranch"]:
                branch = entry["gitBranch"]
            ts = _parse_ts(entry.get("timestamp"))
            if ts is not None:
                timestamps.append(ts)

            etype = entry.get("type")
            message = entry.get("message")
            if not isinstance(message, dict):
                message = {}

            if etype == "assistant":
                b = branches.setdefault(branch, _new_branch())
                if ts is not None:
                    b["first"] = ts if b["first"] is None else min(b["first"], ts)
                    b["last"] = ts if b["last"] is None else max(b["last"], ts)
                model = message.get("model")
                if not (isinstance(model, str) and model and "<" not in model):
                    model = None
                msg_id = message.get("id")
                key = msg_id if msg_id is not None else ("no-id", len(replies))
                day = ts.date().isoformat() if ts is not None else None
                first_branch, first_day = (replies[key][2], replies[key][3]) if key in replies else (branch, day)
                replies[key] = (message.get("usage") or {}, model, first_branch, first_day)
                for block in message.get("content") or []:
                    if not (isinstance(block, dict) and block.get("type") == "tool_use"):
                        continue
                    use_id = block.get("id")
                    if use_id is not None:
                        if use_id in seen_tool_uses:
                            continue
                        seen_tool_uses.add(use_id)
                    name = block.get("name") or "?"
                    tool_counts[name] += 1
                    if name in ("Agent", "Task") and use_id is not None:
                        agent_calls[use_id] = branch
                    if name == "Skill":
                        skill = (block.get("input") or {}).get("skill")
                        if isinstance(skill, str) and skill:
                            skill_counts[skill] += 1
                            b["skills"][skill] += 1

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

    for usage, model, reply_branch, day in replies.values():
        # fast mode is billed at its own rates, so it is priced as a model of its own
        key = (model or "unknown") + (":fast" if usage.get("speed") == "fast" else "")
        b = branches[reply_branch]
        _add_tokens(tokens, usage)
        _add_tokens(tokens_by_model.setdefault(key, zero_priced_tokens()), usage)
        _add_tokens(b["tokens_by_model"].setdefault(key, zero_priced_tokens()), usage)
        _add_tokens(b["days"].setdefault(day, {}).setdefault(key, zero_priced_tokens()), usage)
        if model and "synthetic" not in model:
            models[model] += 1

    return {
        "session_id": session_id,
        "cwd": cwd,
        "timestamps": timestamps,
        "tokens": tokens,
        "tokens_by_model": tokens_by_model,
        "models": models,
        "tool_counts": tool_counts,
        "skill_counts": skill_counts,
        "branches": branches,
        "agent_calls": agent_calls,
        "user_turns": user_turns,
    }


def parse_transcript(path):
    """Return a metrics dict for one session transcript file, or None if it has no usable entries.

    The private keys `_tokens_by_model`, `_branches` and `_agent_calls` carry what
    collect.py needs to price and attribute the session; it removes them before writing.
    """
    raw = scan_transcript(path)
    if raw is None:
        return None
    timestamps = raw["timestamps"]
    started_at = min(timestamps) if timestamps else None
    ended_at = max(timestamps) if timestamps else None
    duration_seconds = None
    if started_at is not None and ended_at is not None:
        duration_seconds = round((ended_at - started_at).total_seconds(), 3)

    session_id = raw["session_id"] or os.path.splitext(os.path.basename(path))[0]
    models = raw["models"]
    model = models.most_common(1)[0][0] if models else None
    cwd = raw["cwd"]
    repo = os.path.basename(cwd.rstrip("/")) if cwd else None
    tool_counts = raw["tool_counts"]
    skill_counts = raw["skill_counts"]

    return {
        "session_id": session_id,
        "repo": repo,
        "cwd": cwd,
        "started_at": started_at.isoformat() if started_at else None,
        "ended_at": ended_at.isoformat() if ended_at else None,
        "duration_seconds": duration_seconds,
        "model": model,
        "tokens": raw["tokens"],
        "tool_calls": {"total": sum(tool_counts.values()), "by_tool": dict(tool_counts)},
        "skills": {"total": sum(skill_counts.values()), "by_skill": dict(skill_counts)},
        "user_turns": raw["user_turns"],
        "_tokens_by_model": raw["tokens_by_model"],
        "_branches": raw["branches"],
        "_agent_calls": raw["agent_calls"],
    }


def parse_subagent(path):
    """Return a subagent transcript's metrics and the Agent call that launched it, or None.

    The launching tool_use id comes from the sibling `.meta.json` Claude Code writes
    beside each subagent transcript; without it the subagent cannot be attributed.
    """
    raw = scan_transcript(path)
    if raw is None:
        return None
    meta_path = path[: -len(".jsonl")] + ".meta.json"
    launched_by = None
    try:
        with open(meta_path, "r", encoding="utf-8") as fh:
            meta = json.load(fh)
        if isinstance(meta, dict) and isinstance(meta.get("toolUseId"), str):
            launched_by = meta["toolUseId"]
    except (OSError, ValueError):
        pass
    raw["launched_by"] = launched_by
    return raw
