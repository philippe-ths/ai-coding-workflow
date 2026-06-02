"""Collect session metrics into the Session Store and regenerate the dashboard.

On-demand, full-rebuild (see docs/adr/0001): every run reprocesses all transcripts
from scratch, so the store can never silently drift. Nothing runs in the background.

Reads:
  ~/.claude/projects/*/*.jsonl   session transcripts (all repos)
  <store-dir>/manifest.jsonl     {session_id, workflow_version, ...} from the SessionStart hook
  <store-dir>/ratings.jsonl      {repo, timestamp, rating} from the /rate skill
Writes:
  <store-dir>/sessions.jsonl     the Session Store, one row per session
  <store-dir>/dashboard.html     the static dashboard

Locations are overridable by env for testing:
  AIW_OBS_DIR        store dir          (default ~/.claude/aiw-observation)
  AIW_PROJECTS_DIR   transcripts root   (default ~/.claude/projects)
  AIW_OBS_NO_OPEN=1  do not open the browser
"""

import glob
import json
import os
import sys
import webbrowser

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashboard  # noqa: E402
from parse import _parse_ts, parse_transcript  # noqa: E402
from pricing import estimate_cost  # noqa: E402


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


def build_rows(sdir, pdir):
    manifest = load_manifest(sdir)
    ratings = _read_jsonl(os.path.join(sdir, "ratings.jsonl"))
    rows = []
    for path in glob.glob(os.path.join(pdir, "*", "*.jsonl")):
        record = parse_transcript(path)
        if record is None:
            continue
        record["estimated_cost_usd"] = estimate_cost(record["model"], record["tokens"])
        man = manifest.get(record["session_id"]) or {}
        record["workflow_version"] = man.get("workflow_version")
        record["rating"] = match_rating(record, ratings)
        rows.append(record)
    rows.sort(key=lambda r: r.get("started_at") or "")
    return rows


def write_store(rows, sdir):
    os.makedirs(sdir, exist_ok=True)
    path = os.path.join(sdir, "sessions.jsonl")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    os.replace(tmp, path)
    return path


def main():
    sdir = store_dir()
    pdir = projects_dir()
    rows = build_rows(sdir, pdir)
    store_path = write_store(rows, sdir)
    html_path = os.path.join(sdir, "dashboard.html")
    with open(html_path, "w", encoding="utf-8") as fh:
        fh.write(dashboard.render(rows))
    rated = sum(1 for r in rows if r.get("rating") is not None)
    print(f"Sessions: {len(rows)} ({rated} rated)")
    print(f"Store:     {store_path}")
    print(f"Dashboard: {html_path}")
    if not os.environ.get("AIW_OBS_NO_OPEN"):
        webbrowser.open("file://" + html_path)


if __name__ == "__main__":
    main()
