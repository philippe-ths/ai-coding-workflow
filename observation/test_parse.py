"""Regression test for the transcript parser and cost estimator.

Run directly: `python3 observation/test_parse.py` (exits non-zero on failure).
Also invoked by scripts/repo-validation.sh. Guards the one place the transcript
format lives (parse.py) against a fixed, hand-computed input.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parse import parse_transcript, scan_transcript  # noqa: E402
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
        rows, tasks, history = collect.build_rows(sdir, PROJECTS)
    by_session = {r["session_id"]: r for r in rows}
    check("sessions", sorted(by_session), ["sess-2", "sess-3", "sess-4"])
    s = by_session.get("sess-2") or {"tokens": {}, "subagents": {"tokens": {}}}
    # each reply counted once: 100 + 1000 + 200 + 50 main, 400 + 80 + 10 subagents
    check("session.tokens.input", s["tokens"].get("input"), 1840)
    check("session.tokens.output", s["tokens"].get("output"), 184)
    check("session.subagents.count", s["subagents"].get("count"), 3)
    check("session.subagents.input", s["subagents"]["tokens"].get("input"), 490)
    # the 1-hour split is a pricing input, not a stored metric
    check("stored token fields", sorted(s["tokens"]), ["cache_creation", "cache_read", "input", "output"])

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
    # day 1: opus-4-8 1200 in / 120 out, sonnet-4-6 400 / 40, haiku-4-5 80 / 8, each priced at its own rate
    check("#7.day1.estimated_cost_usd", day1.get("estimated_cost_usd"), 0.0109)
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
    check_history(rows, tasks, history)


def check_history(rows, tasks, history):
    """A session whose transcript Claude Code deleted keeps every figure it had."""
    import json
    import shutil
    import tempfile

    import collect

    with tempfile.TemporaryDirectory() as tmp:
        sdir, pdir = os.path.join(tmp, "store"), os.path.join(tmp, "projects")
        shutil.copytree(PROJECTS, pdir)
        # an entry from a future history format is kept, though not read
        collect.write_jsonl(history + [{"v": 999, "record": {"session_id": "future"}}], sdir, "history.jsonl")
        # sess-2 carries nested subagents and two of issue 7's branches
        os.remove(os.path.join(pdir, "-x-demo-repo", "sess-2.jsonl"))
        shutil.rmtree(os.path.join(pdir, "-x-demo-repo", "sess-2"))
        rows2, tasks2, history2 = collect.build_rows(sdir, pdir)
        collect.write_jsonl(history2, sdir, "history.jsonl")
        rows3, tasks3, _ = collect.build_rows(sdir, pdir)

    deleted = {r["session_id"]: r.pop("transcript_deleted") for r in rows2}
    check("deleted transcript flagged", deleted, {"sess-2": True, "sess-3": False, "sess-4": False})
    for r in rows:
        r.pop("transcript_deleted")
    check("sessions survive deletion", rows2, rows)
    check("tasks survive deletion", tasks2, tasks)
    for r in rows3:
        r.pop("transcript_deleted")
    check("history survives a second run", (rows3, tasks3), (rows, tasks))
    check("other history format kept", [h["v"] for h in history2].count(999), 1)

    # a reply with no timestamp has no day; that must survive the trip through history.jsonl,
    # and a transcript still on disk that no longer parses is kept from history, not called deleted
    reply = {"type": "assistant", "sessionId": "sess-9", "cwd": "/x/demo-repo", "gitBranch": "feat/9-x",
             "message": {"id": "r9", "model": "claude-opus-4-8", "usage": {"input_tokens": 5, "output_tokens": 1}}}
    with tempfile.TemporaryDirectory() as tmp:
        sdir, pdir = os.path.join(tmp, "store"), os.path.join(tmp, "projects", "-x-demo-repo")
        os.makedirs(pdir)
        transcript = os.path.join(pdir, "sess-9.jsonl")
        with open(transcript, "w") as fh:
            fh.write(json.dumps(reply) + "\n")
        _, before, history9 = collect.build_rows(sdir, os.path.dirname(pdir))
        collect.write_jsonl(history9, sdir, "history.jsonl")
        open(transcript, "w").close()
        rows9, after, _ = collect.build_rows(sdir, os.path.dirname(pdir))
    check("no-timestamp day survives history", after, before)
    check("unparseable transcript not called deleted", [r["transcript_deleted"] for r in rows9], [False])

    sess3 = next(r for r in rows if r["session_id"] == "sess-3")
    ratings = [
        {"repo": "demo-repo", "timestamp": sess3["started_at"], "rating": 3},
        {"repo": "demo-repo", "timestamp": "2020-01-01T00:00:00+00:00", "rating": 1},
    ]
    check("unmatched ratings", [r["rating"] for r in collect.unmatched_ratings(rows, ratings)], [1])
    json.dumps(history2)  # history must be plain JSON


def check_pricing():
    """Prices per model ID at the cited list rates, cache writes split by duration."""
    import json
    import tempfile

    m = 1_000_000
    # opus-5-5: $4 in, $20 out, reads at 0.05x ($0.20), 5m writes $5, 1h writes $8
    check("opus-5-5 cost", estimate_cost("claude-opus-5-5", {
        "input": m, "output": m, "cache_read": m, "cache_creation": m, "cache_creation_1h": 400_000,
    }), 30.4)
    check("dated model id", estimate_cost("claude-haiku-4-5-20251001", {"input": m}), 1.0)
    # the two models carrying most real spend: input, output, read, 5m write each per million
    every = {"input": m, "output": m, "cache_read": m, "cache_creation": m}
    check("opus-5 cost", estimate_cost("claude-opus-5", every), 36.75)
    check("sonnet-5 cost", estimate_cost("claude-sonnet-5", every), 14.7)
    check("fast mode rate", estimate_cost("claude-opus-5:fast", {"input": m}), 10.0)
    # a newer model in a known family is not priced as its predecessor
    check("unknown newer model", estimate_cost("claude-opus-6", {"input": m}), None)

    # a fast reply is keyed apart from standard ones, and the 1h share of its cache writes is kept
    reply = {"type": "assistant", "sessionId": "s", "timestamp": "2026-06-01T10:00:00Z", "message": {
        "id": "r1", "model": "claude-opus-5", "usage": {
            "input_tokens": 10, "output_tokens": 1, "cache_read_input_tokens": 0,
            "cache_creation_input_tokens": 30, "speed": "fast",
            "cache_creation": {"ephemeral_5m_input_tokens": 10, "ephemeral_1h_input_tokens": 20},
        }}}
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as fh:
        fh.write(json.dumps(reply) + "\n")
    try:
        raw = scan_transcript(fh.name)
    finally:
        os.unlink(fh.name)
    by_model = raw["tokens_by_model"]
    check("fast key", sorted(by_model), ["claude-opus-5:fast"])
    check("1h cache writes", by_model.get("claude-opus-5:fast", {}).get("cache_creation_1h"), 20)
    # task and per-day costs are priced from the per-branch maps, so the split must reach them too
    branch = raw["branches"].get(None, {})
    check("1h by branch", branch.get("tokens_by_model", {}).get("claude-opus-5:fast", {}).get("cache_creation_1h"), 20)
    check("1h by day", branch.get("days", {}).get("2026-06-01", {}).get("claude-opus-5:fast", {}).get("cache_creation_1h"), 20)
    import collect

    merged = {}
    collect._merge_tokens(merged, by_model)
    check("1h cache writes merged", merged.get("claude-opus-5:fast", {}).get("cache_creation_1h"), 20)


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

    # estimated cost at opus-4-8 rates: exact hand-computed value
    cost = estimate_cost(rec["model"], rec["tokens"])
    check("estimated_cost_usd", cost, 0.0326)
    # unknown model -> no estimate
    check("estimate_unknown_model", estimate_cost("some-future-model", rec["tokens"]), None)

    check_tasks()
    check_pricing()

    if failures:
        print("PARSER TEST FAILED:")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("parser test: OK")


if __name__ == "__main__":
    main()
