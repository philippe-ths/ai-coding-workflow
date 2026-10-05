"""Collect session metrics into the Session Store and regenerate the dashboard.

On-demand, full-rebuild (see docs/adr/0001): every run reprocesses all transcripts
from scratch, so the store can never silently drift. Nothing runs in the background.

Reads:
  ~/.claude/projects/*/*.jsonl   session transcripts (all repos)
  <store-dir>/manifest.jsonl     {session_id, workflow_version, ...} from the SessionStart hook
  <store-dir>/ratings.jsonl      {repo, timestamp, rating} from the /rate skill
  ~/.claude/projects/*/<session>/subagents/*.jsonl   subagent transcripts, added to the
                                 session and task that launched them
Writes:
  <store-dir>/sessions.jsonl     the Session Store, one row per session
  <store-dir>/tasks.jsonl        one row per task (repo + issue number from the branch name)
  <store-dir>/dashboard.html     the static dashboard

Locations are overridable by env for testing:
  AIW_OBS_DIR        store dir          (default ~/.claude/aiw-observation)
  AIW_PROJECTS_DIR   transcripts root   (default ~/.claude/projects)
  AIW_OBS_NO_OPEN=1  do not open the browser
"""

import glob
import json
import os
import re
import sys
import webbrowser

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashboard  # noqa: E402
from parse import _parse_ts, parse_subagent, parse_transcript  # noqa: E402
from pricing import estimate_cost_by_model  # noqa: E402


def store_dir():
    return os.environ.get("AIW_OBS_DIR") or os.path.expanduser("~/.claude/aiw-observation")


def projects_dir():
    return os.environ.get("AIW_PROJECTS_DIR") or os.path.expanduser("~/.claude/projects")


def _read_jsonl(path):
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def load_manifest(sdir):
    """session_id -> manifest row (last write wins)."""
    by_session = {}
    for row in _read_jsonl(os.path.join(sdir, "manifest.jsonl")):
        sid = row.get("session_id")
        if sid:
            by_session[sid] = row
    return by_session


# A /rate at the very end of a session can be timestamped just past the last
# transcript entry, so allow a short grace window after the session's end.
_RATING_END_GRACE_SECONDS = 600


def match_rating(session, ratings):
    """Latest rating whose repo matches and whose timestamp falls within the session window."""
    start = _parse_ts(session.get("started_at"))
    end = _parse_ts(session.get("ended_at"))
    if start is None or end is None:
        return None
    end_limit = end.timestamp() + _RATING_END_GRACE_SECONDS
    best_ts = None
    best_val = None
    for r in ratings:
        if r.get("repo") != session.get("repo"):
            continue
        rts = _parse_ts(r.get("timestamp"))
        if rts is None or rts < start or rts.timestamp() > end_limit:
            continue
        if best_ts is None or rts >= best_ts:
            best_ts = rts
            best_val = r.get("rating")
    return best_val


_UNTASKED_BRANCHES = ("main", "master", "HEAD")
# The issue number leads the part after the type prefix, unless that part starts with a
# date (kb-maintenance/2026-09-06-ingest). A branch naming two issues (fix/424-421-...) is
# the first one's.
_ISSUE_BRANCH = re.compile(r"^[^/]+/(?!\d{4}-\d{2}-\d{2})(\d+)(?:-|$)")


def task_of(branch):
    """The task a branch works on: '#<n>' for an issue branch, the branch name for any
    other working branch, None for the default branch, detached HEAD, a subagent's
    throwaway worktree branch, or no branch recorded."""
    if not branch or branch in _UNTASKED_BRANCHES or branch.startswith("worktree-agent-"):
        return None
    m = _ISSUE_BRANCH.match(branch)
    return "#" + m.group(1) if m else branch


def _merge_tokens(into, tokens_by_model):
    for model, toks in tokens_by_model.items():
        acc = into.setdefault(model, {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0})
        for k in acc:
            acc[k] += toks.get(k, 0) or 0


def _sum_tokens(tokens_by_model):
    total = {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0}
    for toks in tokens_by_model.values():
        for k in total:
            total[k] += toks.get(k, 0) or 0
    return total


def _resolve_launch_branches(main_calls, subs):
    """Branch each subagent counts against: the branch of the reply that launched it,
    followed up through nested subagents to the session's own reply. None if unknown."""
    owner = {}  # tool_use id -> ("main", branch) or ("sub", index)
    for use_id, branch in main_calls.items():
        owner[use_id] = ("main", branch)
    for i, sub in enumerate(subs):
        for use_id in sub["agent_calls"]:
            owner.setdefault(use_id, ("sub", i))
    resolved = {}

    def resolve(i, depth=0):
        if i in resolved:
            return resolved[i]
        branch = None
        hit = owner.get(subs[i]["launched_by"])
        if hit is not None and depth < 10:
            branch = hit[1] if hit[0] == "main" else resolve(hit[1], depth + 1)
        resolved[i] = branch
        return branch

    return [resolve(i) for i in range(len(subs))]


def _task_acc(tasks, repo, task):
    return tasks.setdefault((repo, task), {
        "tokens_by_model": {}, "days": {}, "branches": set(), "sessions": set(), "subagents": 0,
        "skills": {}, "first": None, "last": None,
    })


def _touch(acc, first, last):
    if first is not None:
        acc["first"] = first if acc["first"] is None else min(acc["first"], first)
    if last is not None:
        acc["last"] = last if acc["last"] is None else max(acc["last"], last)


def _add_days(acc, days):
    for day, tokens_by_model in days.items():
        _merge_tokens(acc["days"].setdefault(day, {}), tokens_by_model)


def _add_skills(acc, skills):
    for k, v in skills.items():
        acc["skills"][k] = acc["skills"].get(k, 0) + v


def build_rows(sdir, pdir):
    """Return (session rows, task rows)."""
    manifest = load_manifest(sdir)
    ratings = _read_jsonl(os.path.join(sdir, "ratings.jsonl"))
    rows = []
    tasks = {}
    for path in glob.glob(os.path.join(pdir, "*", "*.jsonl")):
        record = parse_transcript(path)
        if record is None:
            continue
        tokens_by_model = record.pop("_tokens_by_model")
        branches = record.pop("_branches")
        agent_calls = record.pop("_agent_calls")
        sid = record["session_id"]
        repo = record["repo"]

        for branch, b in branches.items():
            acc = _task_acc(tasks, repo, task_of(branch))
            _merge_tokens(acc["tokens_by_model"], b["tokens_by_model"])
            _add_days(acc, b["days"])
            _add_skills(acc, b["skills"])
            if branch:
                acc["branches"].add(branch)
            acc["sessions"].add(sid)
            _touch(acc, b["first"], b["last"])

        sub_paths = sorted(glob.glob(os.path.join(path[: -len(".jsonl")], "subagents", "*.jsonl")))
        subs = [s for s in (parse_subagent(p) for p in sub_paths) if s is not None]
        sub_tokens_by_model = {}
        for sub, branch in zip(subs, _resolve_launch_branches(agent_calls, subs)):
            _merge_tokens(sub_tokens_by_model, sub["tokens_by_model"])
            acc = _task_acc(tasks, repo, task_of(branch))
            _merge_tokens(acc["tokens_by_model"], sub["tokens_by_model"])
            for sub_branch in sub["branches"].values():
                _add_days(acc, sub_branch["days"])
            _add_skills(acc, sub["skill_counts"])
            if branch:
                acc["branches"].add(branch)
            acc["sessions"].add(sid)
            acc["subagents"] += 1
            ts = sub["timestamps"]
            _touch(acc, min(ts) if ts else None, max(ts) if ts else None)

        all_tokens_by_model = {}
        _merge_tokens(all_tokens_by_model, tokens_by_model)
        _merge_tokens(all_tokens_by_model, sub_tokens_by_model)
        record["tokens"] = _sum_tokens(all_tokens_by_model)
        record["subagents"] = {
            "count": len(subs),
            "tokens": _sum_tokens(sub_tokens_by_model),
            "estimated_cost_usd": estimate_cost_by_model(sub_tokens_by_model),
        }
        record["estimated_cost_usd"] = estimate_cost_by_model(all_tokens_by_model)
        man = manifest.get(sid) or {}
        record["workflow_version"] = man.get("workflow_version")
        record["rating"] = match_rating(record, ratings)
        rows.append(record)
    rows.sort(key=lambda r: r.get("started_at") or "")

    task_rows = []
    for (repo, task), acc in tasks.items():
        task_rows.append({
            "repo": repo,
            "task": task,
            "branches": sorted(acc["branches"]),
            "sessions": len(acc["sessions"]),
            "subagents": acc["subagents"],
            "failure_analyses": acc["skills"].get("aiw-failure-analysis", 0),
            "tokens": _sum_tokens(acc["tokens_by_model"]),
            "estimated_cost_usd": estimate_cost_by_model(acc["tokens_by_model"]),
            # per UTC day, so a date filter can show the part of a task inside its range
            "by_day": {
                day: {"tokens": _sum_tokens(tbm), "estimated_cost_usd": estimate_cost_by_model(tbm)}
                for day, tbm in sorted(acc["days"].items(), key=lambda kv: kv[0] or "")
            },
            "first_seen": acc["first"].isoformat() if acc["first"] else None,
            "last_seen": acc["last"].isoformat() if acc["last"] else None,
        })
    task_rows.sort(key=lambda t: (t["repo"] or "", t["task"] or ""))
    return rows, task_rows


def write_jsonl(rows, sdir, name):
    os.makedirs(sdir, exist_ok=True)
    path = os.path.join(sdir, name)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    os.replace(tmp, path)
    return path


def main():
    sdir = store_dir()
    pdir = projects_dir()
    rows, task_rows = build_rows(sdir, pdir)
    store_path = write_jsonl(rows, sdir, "sessions.jsonl")
    tasks_path = write_jsonl(task_rows, sdir, "tasks.jsonl")
    html_path = os.path.join(sdir, "dashboard.html")
    with open(html_path, "w", encoding="utf-8") as fh:
        fh.write(dashboard.render(rows, task_rows))
    rated = sum(1 for r in rows if r.get("rating") is not None)
    print(f"Sessions: {len(rows)} ({rated} rated)")
    print(f"Tasks:    {sum(1 for t in task_rows if t['task'])}")
    print(f"Store:     {store_path}")
    print(f"Task store: {tasks_path}")
    print(f"Dashboard: {html_path}")
    if not os.environ.get("AIW_OBS_NO_OPEN"):
        webbrowser.open("file://" + html_path)


if __name__ == "__main__":
    main()
