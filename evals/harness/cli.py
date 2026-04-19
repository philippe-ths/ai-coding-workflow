"""Thin CLI wrapper invoked by scripts/run-baseline.sh for one task run."""
from __future__ import annotations

import os
import sys
from pathlib import Path

from .runner import RunOptions, run_once


def main() -> int:
    task_dir = os.environ.get("BASELINE_TASK_DIR")
    if not task_dir:
        print("BASELINE_TASK_DIR is required", file=sys.stderr)
        return 2
    opts = RunOptions(
        agent=os.environ.get("BASELINE_AGENT", "mock"),
        model=os.environ.get("BASELINE_MODEL") or None,
        timeout_seconds=int(os.environ.get("BASELINE_TIMEOUT", "600")),
    )
    record = run_once(Path(task_dir), opts)
    print(
        f"  -> {record['outcome']} run_id={record['run_id']} "
        f"tests_post={record['tests']['post_change_passed']}"
    )
    return 0 if record["outcome"] == "completed" else 1


if __name__ == "__main__":
    sys.exit(main())
