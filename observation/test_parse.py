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

PROJECTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "projects")

failures = []


def check(name, got, want):
    if got != want:
        failures.append(f"{name}: got {got!r}, want {want!r}")


def check_tasks():
    """fixtures/projects/: demo-repo's sess-2 works on main, feat/7-thing, fix/7-retry
    and feat/other-work, with two replies split into repeated entries (the subagent one
    streaming, so only its last output count is whole) and three subagents: one launched
    from feat/7-thing, one nested inside that one, and one with no metadata to say who
    launched it. sess-3 carries on with issue 7 the next day; other-repo has its own #7."""
    import tempfile

    import collect

    with tempfile.TemporaryDirectory() as sdir:
        rows, tasks = collect.build_rows(sdir, PROJECTS)
    by_session = {r["session_id"]: r for r in rows}
    check("sessions", sorted(by_session), ["sess-2", "sess-3", "sess-4"])
    s = by_session.get("sess-2") or {"tokens": {}, "subagents": {"tokens": {}}}
    # each reply counted once: 100 + 1000 + 200 + 50 main, 400 + 80 + 10 subagents
    check("session.tokens.input", s["tokens"].get("input"), 1840)
    check("session.tokens.output", s["tokens"].get("output"), 184)
    check("session.subagents.count", s["subagents"].get("count"), 3)
    check("session.subagents.input", s["subagents"]["tokens"].get("input"), 490)

    by_task = {(t["repo"], t["task"]): t for t in tasks}
    check("task keys", sorted(by_task, key=str), sorted([
        ("demo-repo", "#7"), ("demo-repo", None), ("demo-repo", "feat/other-work"), ("other-repo", "#7"),
    ], key=str))
    t7 = by_task.get(("demo-repo", "#7")) or {}
    # two branches and two sessions of issue 7, plus both nested subagents through the reply that launched them
    check("#7.branches", t7.get("branches"), ["feat/7-thing", "fix/7-retry"])
    check("#7.sessions", t7.get("sessions"), 2)
    check("#7.tokens.input", (t7.get("tokens") or {}).get("input"), 1980)
    check("#7.subagents", t7.get("subagents"), 2)
    check("#7.failure_analyses", t7.get("failure_analyses"), 1)
    day1 = (t7.get("by_day") or {}).get("2026-06-02") or {}
    check("#7.day1.input", (day1.get("tokens") or {}).get("input"), 1680)
    check("#7.day2.input", ((t7.get("by_day") or {}).get("2026-06-03") or {}).get("tokens", {}).get("input"), 300)
    # day 1: opus 1200 in / 120 out, sonnet 400 / 40, haiku 80 / 8, each priced at its own rate
    check("#7.day1.estimated_cost_usd", day1.get("estimated_cost_usd"), 0.0289)
    check("other-repo #7.input", (by_task.get(("other-repo", "#7")) or {}).get("tokens", {}).get("input"), 70)
    check("other.tokens.input", (by_task.get(("demo-repo", "feat/other-work")) or {}).get("tokens", {}).get("input"), 50)
    un = by_task.get(("demo-repo", None)) or {}
    check("unattributed.tokens.input", (un.get("tokens") or {}).get("input"), 110)
    check("unattributed.subagents", un.get("subagents"), 1)
    # a date after the type prefix is not an issue number; a branch naming two issues is the first one's
    check("date branch", collect.task_of("kb-maintenance/2026-09-06-ingest"), "kb-maintenance/2026-09-06-ingest")
    check("two-issue branch", collect.task_of("fix/424-421-one-thread"), "#424")
    check("detached HEAD", collect.task_of("HEAD"), None)
    check("worktree branch", collect.task_of("worktree-agent-a1"), None)


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

    check_tasks()

    if failures:
        print("PARSER TEST FAILED:")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("parser test: OK")


if __name__ == "__main__":
    main()
