"""Reads the workflow version and ruleset hash at run time.

Both values are captured at the start of each baseline run and written into the
per-session JSON. They define the version coordinates on which cross-version
comparison joins.
"""
from __future__ import annotations

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
    envrc = repo_root() / ".envrc"
    if not envrc.exists():
        raise RuntimeError(
            ".envrc not found. Run ./.ai-policy/scripts/update-session-tags.sh first."
        )
    text = envrc.read_text()
    m = re.search(
        r'OTEL_RESOURCE_ATTRIBUTES\s*=\s*"([^"]*)"', text
    )
    if not m:
        raise RuntimeError(
            "OTEL_RESOURCE_ATTRIBUTES export not found in .envrc. "
            "Run ./.ai-policy/scripts/update-session-tags.sh first."
        )
    for pair in m.group(1).split(","):
        k, _, v = pair.partition("=")
        if k.strip() == "ruleset_hash":
            return v.strip()
    raise RuntimeError(
        "ruleset_hash not found in .envrc OTEL_RESOURCE_ATTRIBUTES. "
        "Run ./.ai-policy/scripts/update-session-tags.sh first."
    )
