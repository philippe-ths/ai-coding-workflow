"""Writes per-session JSON records to the baseline results tree.

Path: telemetry/data/baseline/<workflow_version>/<ruleset_hash>/<task_id>/<run_id>.json
See docs/telemetry-schema.md.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterator

from .context import repo_root

BASELINE_ROOT_REL = Path("telemetry") / "data" / "baseline"


def baseline_root() -> Path:
    return repo_root() / BASELINE_ROOT_REL


def result_path(workflow_version: str, ruleset_hash: str, task_id: str, run_id: str) -> Path:
    return baseline_root() / workflow_version / ruleset_hash / task_id / f"{run_id}.json"


def write_result(record: dict[str, Any]) -> Path:
    path = result_path(
        record["workflow_version"],
        record["ruleset_hash"],
        record["task_id"],
        record["run_id"],
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(record, indent=2, sort_keys=True))
    tmp.rename(path)
    return path


def iter_results(workflow_version: str | None = None) -> Iterator[dict[str, Any]]:
    root = baseline_root()
    if not root.exists():
        return
    if workflow_version is not None:
        roots = [root / workflow_version]
    else:
        roots = [d for d in root.iterdir() if d.is_dir()]
    for ver_dir in roots:
        if not ver_dir.exists():
            continue
        for json_file in ver_dir.rglob("*.json"):
            try:
                yield json.loads(json_file.read_text())
            except (OSError, json.JSONDecodeError):
                continue
