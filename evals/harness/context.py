"""Reads the workflow version and ruleset hash at run time.

Both values are captured at the start of each baseline run and written into the
per-session JSON. They define the version coordinates on which cross-version
comparison joins.
"""
from __future__ import annotations

import json
import re
import subprocess
from functools import lru_cache
from pathlib import Path


@lru_cache(maxsize=1)
def repo_root() -> Path:
    out = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
    return Path(out)


def workflow_version() -> str:
    text = (repo_root() / "ai-workflow.md").read_text()
    m = re.search(r"^Version:\s*([^\s]+)", text, re.MULTILINE)
    if not m:
        raise RuntimeError("ai-workflow.md has no Version: header")
    return m.group(1)


def ruleset_hash() -> str:
    settings = json.loads((repo_root() / ".claude" / "settings.json").read_text())
    attrs = settings.get("env", {}).get("OTEL_RESOURCE_ATTRIBUTES", "")
    for pair in attrs.split(","):
        k, _, v = pair.partition("=")
        if k.strip() == "ruleset_hash":
            return v.strip()
    raise RuntimeError(
        "ruleset_hash not found in .claude/settings.json env.OTEL_RESOURCE_ATTRIBUTES. "
        "Run ./.ai-policy/scripts/update-session-tags.sh first."
    )
