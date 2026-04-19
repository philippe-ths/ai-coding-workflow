"""Builds per-session JSON records matching docs/telemetry-schema.md.

The shape is the contract between this harness (Sub-issue D) and the
telemetry stack (Sub-issue C). Any breaking change bumps SCHEMA_VERSION and
must land with a CHANGELOG entry and a docs/telemetry-schema.md update.
"""
from __future__ import annotations

import secrets
from datetime import datetime, timezone
from typing import Any

SCHEMA_VERSION = "0.2"


def new_run_id() -> str:
    return secrets.token_hex(4)


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_record(
    *,
    run_id: str,
    task_id: str,
    workflow_version: str,
    ruleset_hash: str,
    started_at: str,
    ended_at: str,
    duration_seconds: float,
    outcome: str,
    session_id: str | None,
    model: str | None,
    cost_usd: float,
    tokens: dict[str, int],
    tool_calls: dict[str, Any],
    fix_cycles: int,
    checkpoint_reached: bool | None,
    plan_accepted_first_pass: bool | None,
    tests_pre_baseline_passed: bool | None,
    tests_post_change_passed: bool,
    git_commits: int,
    git_lines_added: int,
    git_lines_removed: int,
    git_pr_created: bool,
    transcript_path: str | None,
    notes: list[str],
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "run_id": run_id,
        "task_id": task_id,
        "workflow_version": workflow_version,
        "ruleset_hash": ruleset_hash,
        "started_at": started_at,
        "ended_at": ended_at,
        "duration_seconds": duration_seconds,
        "outcome": outcome,
        "session_id": session_id,
        "model": model,
        "cost_usd": cost_usd,
        "tokens": tokens,
        "tool_calls": tool_calls,
        "fix_cycles": fix_cycles,
        "checkpoint_reached": checkpoint_reached,
        "plan_accepted_first_pass": plan_accepted_first_pass,
        "tests": {
            "pre_baseline_passed": tests_pre_baseline_passed,
            "post_change_passed": tests_post_change_passed,
        },
        "git": {
            "commits": git_commits,
            "lines_added": git_lines_added,
            "lines_removed": git_lines_removed,
            "pr_created": git_pr_created,
        },
        "transcript_path": transcript_path,
        "notes": notes,
    }


REQUIRED_TOP_LEVEL_KEYS = {
    "schema_version",
    "run_id",
    "task_id",
    "workflow_version",
    "ruleset_hash",
    "started_at",
    "ended_at",
    "duration_seconds",
    "outcome",
    "tokens",
    "tool_calls",
    "tests",
    "git",
}


def validate(record: dict[str, Any]) -> None:
    """Raise ValueError if the record is missing required keys or has a bad outcome."""
    missing = REQUIRED_TOP_LEVEL_KEYS - record.keys()
    if missing:
        raise ValueError(f"record missing keys: {sorted(missing)}")
    if record["outcome"] not in {"completed", "failed", "timed_out", "aborted"}:
        raise ValueError(f"bad outcome: {record['outcome']!r}")
