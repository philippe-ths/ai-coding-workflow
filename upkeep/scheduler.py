#!/usr/bin/env python3
"""Choose one project for upkeep and run aiw-upkeep in it.

Machine-level, installed once like observation capture, because no single project
can see the others. One invocation is one decision, logged as one line.

    scheduler.py run [--scheduled] [--dry-run]   decide, and run unless --dry-run
    scheduler.py report [N]                       the last N decisions and what needs the human

A run needs both quota gates to pass, read from the snapshot the status line saves:
weekly use at or below its even pace (100/7 % per elapsed day of the weekly window),
and room left in the 5-hour window. The task-level limit (Light and Standard only)
is not checked here: aiw-upkeep owns it and escalates anything wider.

Overrides, for testing: AIW_UPKEEP_HOME (state dir), AIW_UPKEEP_PROJECTS (transcripts
dir), AIW_UPKEEP_NOW (epoch seconds).
"""
import calendar
import fcntl
import json
import os
import subprocess
import sys
import time
from pathlib import Path

STATE = Path(os.environ.get("AIW_UPKEEP_HOME", Path.home() / ".claude" / "aiw-upkeep"))
PROJECTS = Path(os.environ.get("AIW_UPKEEP_PROJECTS", Path.home() / ".claude" / "projects"))
QUOTA = STATE / "quota.json"
LOG = STATE / "runs.jsonl"
LOCK = STATE / "run.lock"

RECENT_DAYS = 7
WEEKLY_PACE_PER_DAY = 100 / 7
# The human's example of a window worth using: "a session that's about to reset
# but has 40% useage left should be used."
MIN_SESSION_ROOM = 40
SCHEDULED_HOURS = (22,)  # a missed night is skipped, not caught up
RUN_TIMEOUT = 3 * 3600
PROMPT = "do upkeep"
KIND_SKIPS = {"aiw:direction", "aiw:close-proposed"}


def now():
    return int(os.environ.get("AIW_UPKEEP_NOW") or time.time())


def sh(args, cwd=None, timeout=120):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError(f"{' '.join(args[:3])}: {r.stderr.strip()[:300]}")
    return r.stdout


# --- quota -------------------------------------------------------------------

def quota_gates(t):
    """Return (passed, detail). No usable snapshot, or one older than the weekly window, fails."""
    try:
        snap = json.loads(QUOTA.read_text())
        week = snap["rate_limits"]["seven_day"]
        five = snap["rate_limits"]["five_hour"]
        saved = int(snap["saved_at"])
        week_resets = int(week["resets_at"])
        week_used = float(week["used_percentage"])
        five_resets = int(five["resets_at"])
        five_used = float(five["used_percentage"])
    except (OSError, ValueError, KeyError, TypeError):
        return False, {"reason": "no usable quota snapshot"}

    week_start = week_resets - 7 * 86400
    detail = {"snapshot_age_hours": round((t - saved) / 3600, 1)}
    if saved < week_start or t >= week_resets:
        detail["reason"] = "snapshot predates the current weekly window"
        return False, detail

    allowance = min(100.0, WEEKLY_PACE_PER_DAY * (t - week_start) / 86400)
    detail["weekly"] = {"used": week_used, "allowance": round(allowance, 1)}
    session_room = 100.0 if t >= five_resets else 100.0 - five_used
    detail["session_room"] = session_room

    if week_used > allowance:
        detail["reason"] = "weekly use is ahead of pace"
        return False, detail
    if session_room < MIN_SESSION_ROOM:
        detail["reason"] = "too little room in the 5-hour window"
        return False, detail
    return True, detail


# --- candidates ----------------------------------------------------------------

def recent_repos(t):
    """Git repositories the human worked in within RECENT_DAYS, keyed by main checkout."""
    cutoff = t - RECENT_DAYS * 86400
    repos = {}
    for f in PROJECTS.glob("*/*.jsonl"):
        try:
            mtime = int(f.stat().st_mtime)
        except OSError:
            continue
        if mtime < cutoff:
            continue
        cwd, entry = session_origin(f)
        # SDK sessions, the scheduler's own runs among them, are not the human working.
        if not cwd or not entry or entry.startswith("sdk") or not Path(cwd).is_dir():
            continue
        top = main_checkout(cwd)
        if top:
            repos[top] = max(repos.get(top, 0), mtime)
    return repos


def main_checkout(cwd):
    """The main working tree for cwd, so a worktree session counts for its project."""
    try:
        common = sh(["git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"]).strip()
    except (RuntimeError, subprocess.TimeoutExpired, OSError):
        return None
    p = Path(common)
    return str(p.parent) if p.name == ".git" else None


def session_origin(path):
    cwd = entry = None
    try:
        with open(path, errors="replace") as fh:
            for i, line in enumerate(fh):
                if i > 50 or (cwd and entry):
                    break
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if isinstance(d, dict):
                    cwd = cwd or d.get("cwd")
                    entry = entry or d.get("entrypoint")
    except OSError:
        pass
    return cwd, entry


def gh_json(repo, args):
    return json.loads(sh(["gh"] + args, cwd=repo) or "null")


def assess(repo, t):
    """Score one repo by the issues aiw-upkeep would actually pick, or say why it is skipped."""
    if not (Path(repo) / "ai-workflow.md").is_file():
        return {"skip": "workflow not installed"}
    if not (Path(repo) / ".claude" / "skills" / "aiw-upkeep" / "SKILL.md").is_file():
        return {"skip": "aiw-upkeep not loaded (not installed, or parked)"}
    try:
        if sh(["git", "status", "--porcelain"], cwd=repo).strip():
            return {"skip": "uncommitted changes"}
        prs = gh_json(repo, ["pr", "list", "--state", "open", "--label", "aiw:upkeep", "--json", "number"])
        if prs:
            return {"skip": f"open upkeep pull request #{prs[0]['number']}"}
        issues = gh_json(repo, ["issue", "list", "--state", "open", "--label", "aiw:upkeep", "--limit", "200",
                                "--json", "number,createdAt,labels,closedByPullRequestsReferences"])
        closed = gh_json(repo, ["pr", "list", "--state", "closed", "--label", "aiw:upkeep", "--limit", "200",
                                "--json", "mergedAt,closingIssuesReferences"])
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as e:
        return {"skip": f"could not read GitHub: {e}"}
    rejected = {ref["number"] for pr in closed if not pr.get("mergedAt")
                for ref in pr.get("closingIssuesReferences") or []}
    eligible = [i for i in issues
                if not KIND_SKIPS & {l["name"] for l in i["labels"]}
                and not i.get("closedByPullRequestsReferences")
                and i["number"] not in rejected]
    if not eligible:
        return {"skip": "no eligible upkeep issue"}
    days = sum(max(0.0, (t - iso_epoch(i["createdAt"])) / 86400) for i in eligible)
    return {"issues": len(eligible), "issue_days": round(days, 1)}


def iso_epoch(s):
    return calendar.timegm(time.strptime(s, "%Y-%m-%dT%H:%M:%SZ"))


def side_findings(repo):
    """What the human should see whether or not upkeep runs: a broken main, close proposals."""
    out = {}
    try:
        default = gh_json(repo, ["repo", "view", "--json", "defaultBranchRef"])["defaultBranchRef"]["name"]
        runs = gh_json(repo, ["run", "list", "--branch", default, "--limit", "1", "--json", "conclusion,url"])
        if runs and runs[0].get("conclusion") == "failure":
            out["broken_main"] = runs[0]["url"]
        proposals = gh_json(repo, ["issue", "list", "--state", "open", "--label", "aiw:close-proposed",
                                   "--json", "number,title"])
        if proposals:
            out["close_proposed"] = [f"#{p['number']} {p['title']}" for p in proposals]
    except (RuntimeError, ValueError, TypeError, KeyError, OSError, subprocess.TimeoutExpired):
        pass
    return out


# --- run -----------------------------------------------------------------------

def run_upkeep(repo):
    started = time.time()
    try:
        r = subprocess.run(
            ["claude", "-p", PROMPT, "--permission-mode", "auto", "--permission-prompts", "none",
             "--output-format", "json"],
            cwd=repo, capture_output=True, text=True, timeout=RUN_TIMEOUT)
    except subprocess.TimeoutExpired:
        return {"outcome": "timed out", "minutes": round(RUN_TIMEOUT / 60)}
    except OSError as e:
        return {"outcome": f"could not start claude: {e}", "minutes": 0}
    out = {"minutes": round((time.time() - started) / 60, 1), "exit": r.returncode,
           "outcome": "finished" if r.returncode == 0 else "failed"}
    try:
        res = json.loads(r.stdout)
        out.update({"session_id": res.get("session_id"), "usage": res.get("usage"),
                    "result": (res.get("result") or "")[:2000]})
    except ValueError:
        out["result"] = (r.stdout or r.stderr)[-2000:]
    return out


def decide(t, scheduled):
    rec = {"at": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(t)),
           "mode": "scheduled" if scheduled else "manual"}
    lt = time.localtime(t)
    if scheduled and (lt.tm_wday >= 5 or lt.tm_hour not in SCHEDULED_HOURS):
        rec["stopped"] = "outside the weekday 22:00 slot (a missed night is skipped)"
        return rec, None

    repos = [r for r in sorted(recent_repos(t)) if (Path(r) / "ai-workflow.md").is_file()]
    findings = {}
    for repo in repos:
        f = side_findings(repo)
        if f:
            findings[repo] = f
    rec["findings"] = findings

    ok, gate = quota_gates(t)
    rec["quota"] = gate
    if not ok:
        rec["stopped"] = gate["reason"]
        return rec, None

    candidates, skipped = {}, {}
    for repo in repos:
        a = assess(repo, t)
        (skipped if "skip" in a else candidates)[repo] = a.get("skip", a)
    rec["candidates"] = candidates
    rec["skipped"] = skipped
    if not candidates:
        rec["stopped"] = "no project with eligible upkeep"
        return rec, None
    chosen = max(candidates, key=lambda r: candidates[r]["issue_days"])
    rec["chosen"] = chosen
    rec["why"] = f"most issue-days of eligible upkeep ({candidates[chosen]['issue_days']})"
    return rec, chosen


def log(rec):
    STATE.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a") as fh:
        fh.write(json.dumps(rec) + "\n")


def cmd_run(args):
    scheduled = "--scheduled" in args
    dry = "--dry-run" in args
    STATE.mkdir(parents=True, exist_ok=True)
    with open(LOCK, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            rec = {"at": time.strftime("%Y-%m-%dT%H:%M:%S"), "mode": "scheduled" if scheduled else "manual",
                   "stopped": "another upkeep run is in progress"}
            if not dry:
                log(rec)
            print(json.dumps(rec, indent=2))
            return
        rec, chosen = decide(now(), scheduled)
        if chosen and not dry:
            rec["run"] = run_upkeep(chosen)
        if dry:
            rec["dry_run"] = True
        else:
            log(rec)
    print(json.dumps(rec, indent=2))


def cmd_report(args):
    n = int(args[0]) if args else 7
    try:
        lines = LOG.read_text().splitlines()[-n:]
    except OSError:
        print("No upkeep decisions logged yet.")
        return
    latest = None
    for line in lines:
        try:
            r = json.loads(line)
        except ValueError:
            print("(unreadable log line)")
            continue
        head = f"{r.get('at')} {r.get('mode')}: "
        if "chosen" in r:
            run = r.get("run", {})
            print(head + f"{Path(r['chosen']).name}, {r.get('why')}: "
                  f"{run.get('outcome', 'not run')}, {run.get('minutes', '?')} min")
            text = (run.get("result") or "").strip()
            if text:
                print("    " + text.splitlines()[0][:200])
        else:
            print(head + f"no run, {r.get('stopped')}")
        q = r.get("quota", {})
        if "weekly" in q:
            print(f"    quota: week {q['weekly']['used']}% of {q['weekly']['allowance']}% pace, "
                  f"5h room {q['session_room']}%, snapshot {q['snapshot_age_hours']}h old")
        for repo, why in r.get("skipped", {}).items():
            print(f"    skipped {Path(repo).name}: {why}")
        if "findings" in r:
            latest = r
    if latest and latest["findings"]:
        print(f"\nNeeds you, as of {latest['at']} (projects worked in within {RECENT_DAYS} days):")
        for repo, f in latest["findings"].items():
            name = Path(repo).name
            if "broken_main" in f:
                print(f"    {name}: default branch is failing CI, {f['broken_main']}")
            for item in f.get("close_proposed", []):
                print(f"    {name}: close proposed, {item}")


def main(argv):
    if not argv or argv[0] not in ("run", "report"):
        print(__doc__.strip().splitlines()[0])
        print("usage: scheduler.py run [--scheduled] [--dry-run] | report [N]")
        return 2
    {"run": cmd_run, "report": cmd_report}[argv[0]](argv[1:])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
