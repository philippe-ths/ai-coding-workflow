"""Agent implementations that edit a working directory to solve a task.

Two agents are supported:

- ``mock``: copies the task's reference solution/ directory over the workspace.
  Proves the pipeline end-to-end without API cost. Runs on the host.
- ``claude-code``: launches the Claude Code CLI headlessly against the
  workspace. Designed to run inside an Inspect Docker sandbox (see
  ``compose.yaml`` and ``Dockerfile``).

Both return an ``AgentResult`` with the metrics the harness threads into the
per-session JSON. A missing metric is returned as 0 or None rather than raised;
callers decide how to degrade.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class AgentResult:
    outcome: str  # "completed" | "failed" | "timed_out" | "aborted"
    duration_seconds: float
    cost_usd: float = 0.0
    tokens: dict[str, int] = field(
        default_factory=lambda: {
            "input": 0,
            "output": 0,
            "cache_read": 0,
            "cache_creation": 0,
        }
    )
    tool_calls: dict[str, Any] = field(
        default_factory=lambda: {
            "total": 0,
            "accepted": 0,
            "rejected": 0,
            "by_tool": {},
        }
    )
    session_id: str | None = None
    model: str | None = None
    notes: list[str] = field(default_factory=list)


def run_mock_agent(task_dir: Path, workspace: Path) -> AgentResult:
    solution = task_dir / "solution"
    if not solution.exists():
        return AgentResult(
            outcome="aborted",
            duration_seconds=0.0,
            notes=[f"mock agent: no solution/ at {solution}"],
        )
    start = time.monotonic()
    for src in solution.rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(solution)
        dst = workspace / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    duration = time.monotonic() - start
    return AgentResult(
        outcome="completed",
        duration_seconds=duration,
        model="mock",
        notes=["mock agent: copied reference solution"],
    )


def run_claude_code_agent(
    prompt: str,
    workspace: Path,
    *,
    timeout_seconds: int = 600,
    model: str | None = None,
) -> AgentResult:
    """Invoke the ``claude`` CLI headlessly against ``workspace``.

    Designed for use inside a Docker sandbox where ``claude`` is installed and
    ``ANTHROPIC_API_KEY`` is available in the environment.
    """
    cmd = [
        "claude",
        "-p",
        prompt,
        "--output-format",
        "stream-json",
        "--verbose",
        "--dangerously-skip-permissions",
    ]
    if model:
        cmd += ["--model", model]

    started = time.monotonic()
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            env={**os.environ},
        )
    except FileNotFoundError:
        return AgentResult(
            outcome="aborted",
            duration_seconds=time.monotonic() - started,
            notes=["claude CLI not found on PATH"],
        )
    except subprocess.TimeoutExpired:
        return AgentResult(
            outcome="timed_out",
            duration_seconds=time.monotonic() - started,
            notes=[f"claude CLI exceeded {timeout_seconds}s"],
        )
    duration = time.monotonic() - started
    metrics = _parse_stream_json(proc.stdout)
    outcome = "completed" if proc.returncode == 0 else "failed"
    result = AgentResult(
        outcome=outcome,
        duration_seconds=duration,
        cost_usd=metrics["cost_usd"],
        tokens=metrics["tokens"],
        tool_calls=metrics["tool_calls"],
        session_id=metrics["session_id"],
        model=metrics["model"],
        notes=metrics["notes"],
    )
    if proc.returncode != 0:
        result.notes.append(f"claude exit={proc.returncode} stderr={proc.stderr[-400:]}")
    return result


def _parse_stream_json(stdout: str) -> dict[str, Any]:
    """Parse Claude Code's stream-json output into harness metrics.

    Best effort — missing fields degrade to zeros. The exact Claude Code
    stream-json event shape is documented by the CLI and is not pinned here;
    this parser reads only the well-known keys.
    """
    tokens = {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0}
    tool_by: dict[str, dict[str, int]] = {}
    tool_total = tool_accepted = tool_rejected = 0
    cost_usd = 0.0
    session_id: str | None = None
    model: str | None = None
    notes: list[str] = []
    result_usage: dict | None = None

    for raw in stdout.splitlines():
        line = raw.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        session_id = session_id or ev.get("session_id")
        etype = ev.get("type")
        if etype == "system" and ev.get("subtype") == "init":
            model = model or ev.get("model")
        elif etype == "assistant":
            for block in (ev.get("message") or {}).get("content") or []:
                if isinstance(block, dict) and block.get("type") == "tool_use":
                    tool_total += 1
                    tool_accepted += 1
                    name = block.get("name") or "unknown"
                    slot = tool_by.setdefault(name, {"accepted": 0, "rejected": 0})
                    slot["accepted"] += 1
        elif etype == "user":
            for block in (ev.get("message") or {}).get("content") or []:
                if isinstance(block, dict) and block.get("type") == "tool_result" and block.get("is_error"):
                    tool_rejected += 1
                    name = block.get("tool_name") or "unknown"
                    slot = tool_by.setdefault(name, {"accepted": 0, "rejected": 0})
                    slot["rejected"] += 1
        elif etype == "result":
            cost_usd += float(ev.get("total_cost_usd", 0.0) or 0.0)
            result_usage = ev.get("usage") or result_usage

    if result_usage:
        tokens["input"] = int(result_usage.get("input_tokens", 0) or 0)
        tokens["output"] = int(result_usage.get("output_tokens", 0) or 0)
        tokens["cache_read"] = int(result_usage.get("cache_read_input_tokens", 0) or 0)
        tokens["cache_creation"] = int(result_usage.get("cache_creation_input_tokens", 0) or 0)
    return {
        "tokens": tokens,
        "tool_calls": {
            "total": tool_total,
            "accepted": tool_accepted,
            "rejected": tool_rejected,
            "by_tool": tool_by,
        },
        "cost_usd": cost_usd,
        "session_id": session_id,
        "model": model,
        "notes": notes,
    }
