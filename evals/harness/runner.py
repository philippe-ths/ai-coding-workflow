"""Glues agent + grader + schema + results into one baseline run.

Used by ``scripts/run-baseline.sh``. Deliberately does not use Inspect yet:
Inspect adds value for dataset / scorer plumbing but is not required to produce
a schema-conformant JSON for a single task. A later iteration can replace this
runner with an Inspect Task + solver without changing the on-disk contract.
"""
from __future__ import annotations

import shutil
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

from . import agents, schema
from .context import ruleset_hash, workflow_version
from .grader import grade
from .results import write_result


@dataclass
class RunOptions:
    agent: str = "mock"  # "mock" | "claude-code"
    model: str | None = None
    timeout_seconds: int = 600


def _copy_starter(task_dir: Path, workspace: Path) -> None:
    starter = task_dir / "starter"
    if not starter.exists():
        raise RuntimeError(f"task {task_dir.name} has no starter/")
    for src in starter.rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(starter)
        dst = workspace / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def _read_prompt(task_dir: Path) -> str:
    spec = (task_dir / "spec.md").read_text()
    marker = "## Prompt"
    if marker in spec:
        return spec.split(marker, 1)[1].strip()
    return spec.strip()


def run_once(task_dir: Path, opts: RunOptions) -> dict:
    task_id = task_dir.name
    run_id = schema.new_run_id()
    started = time.time()
    started_at = schema.utcnow_iso()

    with tempfile.TemporaryDirectory(prefix=f"baseline-{task_id}-") as tmp:
        workspace = Path(tmp)
        _copy_starter(task_dir, workspace)
        prompt = _read_prompt(task_dir)

        if opts.agent == "mock":
            agent_result = agents.run_mock_agent(task_dir, workspace)
        elif opts.agent == "claude-code":
            agent_result = agents.run_claude_code_agent(
                prompt,
                workspace,
                timeout_seconds=opts.timeout_seconds,
                model=opts.model,
            )
        else:
            raise ValueError(f"unknown agent: {opts.agent!r}")

        grade_result = grade(task_dir, workspace) if agent_result.outcome == "completed" else None

    ended = time.time()
    ended_at = schema.utcnow_iso()
    duration = ended - started

    tests_post = bool(grade_result.passed) if grade_result else False
    outcome = agent_result.outcome
    if outcome == "completed" and not tests_post:
        outcome = "failed"

    notes = list(agent_result.notes)
    if grade_result and not grade_result.passed:
        notes.append(f"grader exit={grade_result.exit_code}")
        if grade_result.stdout:
            notes.append(f"grader stdout (tail): {grade_result.stdout[-400:]}")

    record = schema.build_record(
        run_id=run_id,
        task_id=task_id,
        workflow_version=workflow_version(),
        ruleset_hash=ruleset_hash(),
        started_at=started_at,
        ended_at=ended_at,
        duration_seconds=duration,
        outcome=outcome,
        session_id=agent_result.session_id,
        model=agent_result.model,
        cost_usd=agent_result.cost_usd,
        tokens=agent_result.tokens,
        tool_calls=agent_result.tool_calls,
        fix_cycles=0,
        checkpoint_reached=None,
        plan_accepted_first_pass=None,
        tests_pre_baseline_passed=None,
        tests_post_change_passed=tests_post,
        git_commits=0,
        git_lines_added=0,
        git_lines_removed=0,
        git_pr_created=False,
        transcript_path=None,
        notes=notes,
    )
    schema.validate(record)
    write_result(record)
    return record
