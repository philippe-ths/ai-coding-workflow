"""Runs the hidden pytest grader for a baseline task.

The grader/ directory lives beside the task definition but is copied into the
workspace only after the agent is done. This keeps hidden tests out of the
agent's view while still running them against the agent's final state.
"""
from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class GradeResult:
    passed: bool
    exit_code: int
    stdout: str
    stderr: str


def grade(task_dir: Path, workspace: Path, *, timeout_seconds: int = 120) -> GradeResult:
    grader_dir = task_dir / "grader"
    if not grader_dir.exists():
        return GradeResult(
            passed=False,
            exit_code=-1,
            stdout="",
            stderr=f"no grader/ directory at {grader_dir}",
        )
    grader_dst = workspace / "_grader"
    if grader_dst.exists():
        shutil.rmtree(grader_dst)
    shutil.copytree(grader_dir, grader_dst)
    try:
        proc = subprocess.run(
            ["python", "-m", "pytest", "-q", "_grader"],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as exc:
        return GradeResult(
            passed=False,
            exit_code=-1,
            stdout=exc.stdout or "",
            stderr=(exc.stderr or "") + f"\npytest exceeded {timeout_seconds}s",
        )
    return GradeResult(
        passed=proc.returncode == 0,
        exit_code=proc.returncode,
        stdout=proc.stdout,
        stderr=proc.stderr,
    )
