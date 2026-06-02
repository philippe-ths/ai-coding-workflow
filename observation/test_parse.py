"""Regression test for the transcript parser and cost estimator.

Run directly: `python3 observation/test_parse.py` (exits non-zero on failure).
Also invoked by scripts/repo-validation.sh. Guards the one place the transcript
format lives (parse.py) against a fixed, hand-computed input.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parse import parse_transcript  # noqa: E402
from pricing import estimate_cost  # noqa: E402

FIXTURE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "sample-transcript.jsonl")

failures = []


def check(name, got, want):
    if got != want:
        failures.append(f"{name}: got {got!r}, want {want!r}")


def main():
    rec = parse_transcript(FIXTURE)
    assert rec is not None, "parser returned None on fixture"

    check("session_id", rec["session_id"], "fixture-session-001")
    check("repo", rec["repo"], "demo-repo")
    check("model", rec["model"], "claude-opus-4-8")
    check("duration_seconds", rec["duration_seconds"], 60.0)
    check("started_at", rec["started_at"], "2026-06-01T10:00:00+00:00")
    check("ended_at", rec["ended_at"], "2026-06-01T10:01:00+00:00")

    # tokens summed across the three assistant entries
    check("tokens.input", rec["tokens"]["input"], 3500)
    check("tokens.output", rec["tokens"]["output"], 550)
    check("tokens.cache_read", rec["tokens"]["cache_read"], 1500)
    check("tokens.cache_creation", rec["tokens"]["cache_creation"], 100)

    # tool calls: Read, Edit, Skill, Bash
    check("tool_calls.total", rec["tool_calls"]["total"], 4)
    check("by_tool.Read", rec["tool_calls"]["by_tool"].get("Read"), 1)
    check("by_tool.Skill", rec["tool_calls"]["by_tool"].get("Skill"), 1)

    # skills: only aiw-testing fired once
    check("skills.total", rec["skills"]["total"], 1)
    check("skills.aiw-testing", rec["skills"]["by_skill"].get("aiw-testing"), 1)

    # user_turns: 2 human prompts (string + text block); injected/tool_result/sidechain excluded
    check("user_turns", rec["user_turns"], 2)

    # estimated cost (opus rates): exact hand-computed value
    cost = estimate_cost(rec["model"], rec["tokens"])
    check("estimated_cost_usd", cost, 0.0979)
    # unknown model -> no estimate
    check("estimate_unknown_model", estimate_cost("some-future-model", rec["tokens"]), None)

    if failures:
        print("PARSER TEST FAILED:")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("parser test: OK")


if __name__ == "__main__":
    main()
