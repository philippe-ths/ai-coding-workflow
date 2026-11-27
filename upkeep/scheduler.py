#!/usr/bin/env python3
"""Choose one project for upkeep and run aiw-upkeep in it.

Machine-level, installed once like observation capture, because no single project
can see the others. One invocation is one decision, logged as one line.

    scheduler.py run [--scheduled] [--dry-run]   decide, and run unless --dry-run
    scheduler.py report [N]                       the last N decisions and what needs the human
    scheduler.py deploy                           fast-forward each deploy-projects checkout, run its hook

A run needs both quota gates to pass, read from the snapshot the status line saves:
weekly use at or below its even pace (100/7 % per elapsed day of the weekly window),
and room left in the 5-hour window. The task-level limit (Light and Standard only)
is not checked here: aiw-upkeep owns it and escalates anything wider.

A project whose path is a line of `excluded-projects` in the state dir is never picked.

`deploy` touches only the paths listed in `deploy-projects` in the state dir, the human's own
tools and never a client's: it fast-forwards a clean main checkout on its default branch to
the remote, then runs the repository's executable scripts/deploy.sh, if any, with the last
deployed and the new commit, until the hook succeeds on that commit. Each pass then updates,
with that checkout's scripts/update.sh, every project Claude Code has run in whose aiw copy
is gitignored and older, while the listed aiw checkout is clean on its default branch.

Overrides, for testing: AIW_UPKEEP_HOME (state dir), AIW_UPKEEP_PROJECTS (transcripts
dir), AIW_UPKEEP_NOW (epoch seconds).
"""
import calendar
import fcntl
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

STATE = Path(os.environ.get("AIW_UPKEEP_HOME", Path.home() / ".claude" / "aiw-upkeep"))
PROJECTS = Path(os.environ.get("AIW_UPKEEP_PROJECTS", Path.home() / ".claude" / "projects"))
QUOTA = STATE / "quota.json"
LOG = STATE / "runs.jsonl"
LOCK = STATE / "run.lock"
PENDING = STATE / "work-mode-pending.json"
EXCLUDED = STATE / "excluded-projects"
DEPLOY_PROJECTS = STATE / "deploy-projects"
DEPLOY_STATE = STATE / "deploy-state.json"
DEPLOY_LOG = STATE / "deploys.jsonl"
DEPLOY_LOCK = STATE / "deploy.lock"
DEPLOY_HOOK = "scripts/deploy.sh"
DEPLOY_HOOK_TIMEOUT = 600
AIW_SYNC_STATE = STATE / "aiw-sync-state.json"
AIW_UPDATE_TIMEOUT = 300

RECENT_DAYS = 7
WEEKLY_PACE_PER_DAY = 100 / 7
# The human's example of a window worth using: "a session that's about to reset
# but has 40% useage left should be used."
MIN_SESSION_ROOM = 40
SCHEDULED_HOUR = 22
# launchd fires on time when the machine is awake and on wake when it was not, so a
# start after the slot's first minute means it was asleep at 22:00: the night is skipped.
SCHEDULED_GRACE_SECONDS = 60
RUN_TIMEOUT = 3 * 3600
# A session this recent may still be open; switching branch or mode under it would disturb it.
ACTIVE_SECONDS = 30 * 60
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
    try:
        if repo in EXCLUDED.read_text().split("\n"):
            return {"skip": "excluded by the human"}
    except OSError:
        pass
    if not (Path(repo) / "ai-workflow.md").is_file():
        return {"skip": "workflow not installed"}
    parked = in_work_mode(repo)
    if not parked and not (Path(repo) / ".claude" / "skills" / "aiw-upkeep" / "SKILL.md").is_file():
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
        return {"skip": f"could not read GitHub: {str(e).splitlines()[0] if str(e) else type(e).__name__}"}
    rejected = {ref["number"] for pr in closed if not pr.get("mergedAt")
                for ref in pr.get("closingIssuesReferences") or []}
    eligible = [i for i in issues
                if not KIND_SKIPS & {l["name"] for l in i["labels"]}
                and not i.get("closedByPullRequestsReferences")
                and i["number"] not in rejected]
    if not eligible:
        return {"skip": "no eligible upkeep issue"}
    days = sum(max(0.0, (t - iso_epoch(i["createdAt"])) / 86400) for i in eligible)
    out = {"issues": len(eligible), "issue_days": round(days, 1)}
    if parked:
        out["work_mode"] = True
    return out


def in_work_mode(repo):
    """A project in Work Mode that its own scripts/mode.sh can switch for the run.

    Work Mode parks every aiw-* skill but issue creation and swaps in its own CLAUDE.md, so a
    run there would lack the Task Flow aiw-upkeep relies on. The run happens in Build Mode.
    """
    r = Path(repo)
    try:
        mode = (r / ".claude" / "mode").read_text().strip()
    except OSError:
        return False
    return (mode == "work" and os.access(r / "scripts" / "mode.sh", os.X_OK)
            and any((r / ".claude" / d / "aiw-upkeep" / "SKILL.md").is_file() for d in ("skills-off", "skills")))


def switch_mode(repo, mode):
    """Run the project's own mode switch; return an error string, or None on success."""
    try:
        sh([str(Path(repo) / "scripts" / "mode.sh"), mode], cwd=repo)
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as e:
        return f"scripts/mode.sh {mode} failed: {str(e).splitlines()[0] if str(e) else type(e).__name__}"
    return None


def tree_state(repo):
    """Branch and status, to tell whether the flip left the checkout as it found it."""
    try:
        return (sh(["git", "branch", "--show-current"], cwd=repo).strip(),
                sh(["git", "status", "--porcelain"], cwd=repo))
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as e:
        return ("?", f"unreadable: {e}")


def pending():
    try:
        return [p for p in json.loads(PENDING.read_text()) if isinstance(p, str)]
    except (OSError, ValueError, TypeError):
        return []


def set_pending(repo, on):
    """Track the projects a run switched to Build and has not yet switched back."""
    repos = [p for p in pending() if p != repo] + ([repo] if on else [])
    if repos:
        tmp = PENDING.with_suffix(".tmp")
        tmp.write_text(json.dumps(repos))
        os.replace(tmp, PENDING)
    else:
        PENDING.unlink(missing_ok=True)


def restore_work_mode(repo, before):
    """Switch back to Work, clear its pending entry, and say what is not as it was."""
    out = {}
    back = switch_mode(repo, "work")
    if back:
        out["mode_restore"] = back
    else:
        set_pending(repo, False)
    branch, status = tree_state(repo)
    if (branch, status) != before:
        out["tree_changed"] = (f"on {branch} (was {before[0]}); "
                               + ("; ".join(status.strip().splitlines()[:5]) or "clean"))
    return out


def run_in_build_mode(repo, run, result):
    """Switch a Work Mode project to Build for the run and back to Work whatever happens.

    Fills `result` in place, so a run cut short by SIGTERM still leaves a record. A pending
    entry names the project before the switch, so a hard kill is repaired by a later invocation.
    """
    before = tree_state(repo)
    set_pending(repo, True)
    try:
        err = switch_mode(repo, "build")
        if not err and not (Path(repo) / ".claude" / "skills" / "aiw-upkeep" / "SKILL.md").is_file():
            err = "aiw-upkeep missing after switching to build"
        if not err and tree_state(repo) != before:
            err = "switching to build changed the tree, so the run would start dirty"
        if err:
            result.update({"outcome": "not run", "minutes": 0, "mode_switch": err})
        else:
            result["mode_switch"] = "ran in build mode"
            try:
                result.update(run())
            except Exception as e:  # the switch back and the log line matter more than the traceback
                result.update({"outcome": f"error: {type(e).__name__}: {e}", "minutes": 0})
    finally:
        ignore_sigterm()
        result.update(restore_work_mode(repo, before))
    return result


def ignore_sigterm():
    """Cleanup is not to be cut short by a second SIGTERM."""
    try:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
    except ValueError:  # not the main thread
        pass


def repair_pending(recent, t):
    """Put back Work Mode for projects a killed run left in Build Mode, unless in use."""
    done = []
    for repo in pending():
        r = Path(repo)
        # The mode scripts write .claude/mode last, so a kill mid-switch leaves the skills live
        # under a "work" marker: judge by whether aiw-upkeep is loaded, not by the marker.
        if not (r / ".claude" / "skills" / "aiw-upkeep" / "SKILL.md").is_file():
            set_pending(repo, False)
            done.append({"repo": repo, "restored": "already back in work mode"})
            continue
        if t - recent.get(repo, 0) < ACTIVE_SECONDS:
            done.append({"repo": repo, "error": "in use, left in build mode until the next run"})
            continue
        out = restore_work_mode(repo, tree_state(repo))
        done.append({"repo": repo, **({"restored": True} if "mode_restore" not in out else {"error": out["mode_restore"]}),
                     **({"tree_changed": out["tree_changed"]} if "tree_changed" in out else {})})
    return done


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
        return None
    return out


# --- run -----------------------------------------------------------------------

def run_upkeep(repo):
    started = time.time()
    # Hold off idle sleep for the length of the run; a run cut off mid-task leaves work half done.
    awake = ["caffeinate", "-i"] if shutil.which("caffeinate") else []
    try:
        r = subprocess.run(
            awake + ["claude", "-p", PROMPT, "--permission-mode", "auto", "--permission-prompts", "none",
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
    if scheduled and (lt.tm_wday >= 5 or lt.tm_hour != SCHEDULED_HOUR
                      or lt.tm_min * 60 + lt.tm_sec > SCHEDULED_GRACE_SECONDS):
        rec["stopped"] = "not started at 22:00 on a weekday (asleep then, or outside the slot); the night is skipped"
        return rec, None

    recent = recent_repos(t)
    repos = [r for r in sorted(recent) if (Path(r) / "ai-workflow.md").is_file()]
    findings, read_any = {}, False
    for repo in repos:
        f = side_findings(repo)
        read_any = read_any or f is not None
        if f:
            findings[repo] = f
    # Recorded only when GitHub answered, so an offline night leaves the last findings standing.
    if read_any:
        rec["findings"] = findings

    ok, gate = quota_gates(t)
    rec["quota"] = gate
    if not ok:
        rec["stopped"] = gate["reason"]
        return rec, None

    candidates, skipped = {}, {}
    for repo in repos:
        if t - recent[repo] < ACTIVE_SECONDS:
            skipped[repo] = f"in use: a session was active in the last {ACTIVE_SECONDS // 60} minutes"
            continue
        a = assess(repo, t)
        (skipped if "skip" in a else candidates)[repo] = a.get("skip", a)
    rec["candidates"] = candidates
    rec["skipped"] = skipped
    unread = [r for r, why in skipped.items() if why.startswith("could not read GitHub")]
    if not candidates and unread:
        # Unread projects may hold eligible upkeep, so "none eligible" would be a guess.
        rec["stopped"] = f"could not read GitHub for {len(unread)} project(s)"
        return rec, None
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
        # launchd sends SIGTERM on logout, shutdown or reinstall; raising SystemExit lets the
        # cleanup blocks below switch Work Mode back and write the log line.
        signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
        t = now()
        rec = {"at": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(t)),
               "mode": "scheduled" if scheduled else "manual", "stopped": "interrupted before a decision"}
        try:
            if dry:
                if pending():
                    rec["pending_repair"] = pending()
            elif pending():
                rec["repaired"] = repair_pending(recent_repos(t), t)
            decided, chosen = decide(t, scheduled)
            rec.pop("stopped")
            rec.update(decided)
            if chosen and not dry:
                rec["run"] = {"outcome": "interrupted", "minutes": 0}
                if rec["candidates"][chosen].get("work_mode"):
                    run_in_build_mode(chosen, lambda: run_upkeep(chosen), rec["run"])
                else:
                    rec["run"].update(run_upkeep(chosen))
        finally:
            ignore_sigterm()
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
        print_deploy_needs()
        return
    latest = None
    records = []
    for line in lines:
        try:
            r = json.loads(line)
        except ValueError:
            r = None
        if isinstance(r, dict):
            records.append(r)
        else:
            print("(unreadable log line)")
    for r in sorted(records, key=lambda r: str(r.get("at") or "")):
        head = f"{r.get('at')} {r.get('mode')}: "
        if "chosen" in r:
            run = r.get("run", {})
            print(head + f"{Path(r['chosen']).name}, {r.get('why')}: "
                  f"{run.get('outcome', 'not run')}, {run.get('minutes', '?')} min")
            if run.get("mode_switch"):
                print(f"    {run['mode_switch']}")
            if run.get("mode_restore"):
                print(f"    WORK MODE NOT RESTORED in {Path(r['chosen']).name}: {run['mode_restore']}")
            if run.get("tree_changed"):
                print(f"    CHECKOUT NOT AS IT WAS in {Path(r['chosen']).name}: {run['tree_changed']}")
            text = (run.get("result") or "").strip()
            if text:
                print("    " + text.splitlines()[0][:200])
        else:
            print(head + f"no run, {r.get('stopped')}")
        reps = r.get("repaired") or []
        for rep in reps if isinstance(reps, list) else [reps]:
            name = Path(rep.get("repo", "?")).name
            if rep.get("error"):
                print(f"    WORK MODE NOT RESTORED in {name} after a killed run: {rep['error']}")
            else:
                print(f"    repaired a killed run: {name} back in work mode")
            if rep.get("tree_changed"):
                print(f"    CHECKOUT NOT AS IT WAS in {name}: {rep['tree_changed']}")
        q = r.get("quota", {})
        if "weekly" in q:
            print(f"    quota: week {q['weekly']['used']}% of {q['weekly']['allowance']}% pace, "
                  f"5h room {q['session_room']}%, snapshot {q['snapshot_age_hours']}h old")
        for repo, a in r.get("candidates", {}).items():
            if repo != r.get("chosen"):
                print(f"    candidate {Path(repo).name}: {a['issues']} issues, {a['issue_days']} issue-days")
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


    print_deploy_needs()


# --- deploy --------------------------------------------------------------------
# The human's own tools run from their main checkout, and a merge on GitHub leaves that
# checkout behind until someone pulls it. Client projects never deploy this way: only a
# path listed in deploy-projects is touched, and only by a fast-forward of its default branch.

def deploy_projects():
    try:
        lines = DEPLOY_PROJECTS.read_text().splitlines()
    except OSError:
        return []
    return [l.strip() for l in lines if l.strip() and not l.strip().startswith("#")]


def deploy_state():
    try:
        d = json.loads(DEPLOY_STATE.read_text())
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def deploy_one(repo, last):
    """Bring one main checkout up to its remote default branch and run its deploy hook.

    Returns (status, detail). `last` is the commit the hook last succeeded on, so a failed
    hook is retried on the next pass even when the pull itself has nothing new to bring.
    """
    if not (Path(repo) / ".git").exists():
        return "blocked", {"why": "not a git checkout"}
    try:
        try:
            sh(["git", "fetch", "--quiet", "origin"], cwd=repo, timeout=120)
        except (RuntimeError, subprocess.TimeoutExpired) as e:
            return "unreachable", {"why": "could not fetch origin: " + (str(e).splitlines() or ["timed out"])[0]}
        default = sh(["git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD"], cwd=repo).strip()
        branch = sh(["git", "branch", "--show-current"], cwd=repo).strip()
        behind = int(sh(["git", "rev-list", "--count", f"HEAD..{default}"], cwd=repo).strip() or 0)
        why = None
        if f"origin/{branch}" != default:
            why = f"main checkout is on {branch or 'a detached HEAD'}, not {default}"
        elif sh(["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo).strip():
            why = "main checkout has uncommitted changes"
        if why:
            # Nothing merged is missing from what is checked out, so nothing waits on this.
            return ("blocked", {"why": f"{why}; {behind} merged commit(s) not live"}) if behind \
                else ("current", {})
        before = sh(["git", "rev-parse", "HEAD"], cwd=repo).strip()
        # Without --no-overwrite-ignore, a merge that starts tracking a path replaces an
        # ignored local file there (a .env, say) without a word.
        sh(["git", "merge", "--ff-only", "--no-overwrite-ignore", "--quiet", default], cwd=repo)
        after = sh(["git", "rev-parse", "HEAD"], cwd=repo).strip()
        pulled = int(sh(["git", "rev-list", "--count", f"{before}..{after}"], cwd=repo).strip() or 0)
    except (RuntimeError, OSError, subprocess.TimeoutExpired, ValueError) as e:
        return "failed", {"why": str(e).splitlines()[0] if str(e) else type(e).__name__}
    detail = {"head": after}
    if pulled:
        detail["pulled"] = pulled
    hook = Path(repo) / DEPLOY_HOOK
    if not os.access(hook, os.X_OK) or after == last:
        return "deployed", detail
    try:
        r = subprocess.run([str(hook), last or "", after], cwd=repo, capture_output=True, text=True,
                           timeout=DEPLOY_HOOK_TIMEOUT)
    except subprocess.TimeoutExpired:
        return "failed", {**detail, "why": f"{DEPLOY_HOOK} timed out"}
    except OSError as e:
        return "failed", {**detail, "why": f"{DEPLOY_HOOK} could not start: {e}"}
    if r.returncode != 0:
        tail = (r.stderr or r.stdout).strip().splitlines()
        return "failed", {**detail, "why": f"{DEPLOY_HOOK} exited {r.returncode}"
                          + (f": {tail[-1][:200]}" if tail else "")}
    detail["hook"] = "ran"
    return "deployed", detail


def cmd_deploy(args):
    STATE.mkdir(parents=True, exist_ok=True)
    with open(DEPLOY_LOCK, "w") as lock, open(LOCK, "a") as run_lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            # A nightly run works in a main checkout and switches its branch; wait it out
            # rather than race it. Released at once: held, it would make a run starting now
            # stop as "in progress" and lose the night.
            fcntl.flock(run_lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
            fcntl.flock(run_lock, fcntl.LOCK_UN)
        except OSError:
            return
        state = deploy_state()
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(now()))
        for repo in deploy_projects():
            prev = state.get(repo, {})
            status, detail = deploy_one(repo, prev.get("deployed"))
            if status == "current" and prev.get("status") == "failed":
                # Off the default branch with nothing new merged; the failed hook still waits.
                status, detail = "failed", {"why": prev.get("why")}
            changed = status != prev.get("status") or waiting(detail.get("why")) != waiting(prev.get("why"))
            # "at" is when this status began, so the report can say how long work has waited.
            entry = {"status": status, "at": stamp if changed else prev.get("at", stamp),
                     "deployed": detail["head"] if status == "deployed" else prev.get("deployed")}
            if "why" in detail:
                entry["why"] = detail["why"]
            # Log what changed, not every quiet pass: a pull, a hook run, or a new status.
            if changed or detail.get("pulled") or detail.get("hook"):
                with open(DEPLOY_LOG, "a") as fh:
                    fh.write(json.dumps({"at": stamp, "repo": repo, "status": status, **detail}) + "\n")
            state[repo] = entry
        for repo in [r for r in state if r not in deploy_projects()]:
            del state[repo]
        write_json(DEPLOY_STATE, state)
        sync_aiw()


def write_json(path, data):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    os.replace(tmp, path)


def waiting(why):
    """The reason without its commit count, so a further merge does not restart the wait."""
    return re.sub(r"; \d+ merged commit\(s\) not live$", "", why or "")


def print_deploy_needs():
    needs = [(r, e) for r, e in deploy_state().items() if e.get("status") not in ("deployed", "current")]
    if needs:
        print("\nDeploys needing a look (deploy-projects):")
        for repo, e in needs:
            print(f"    {Path(repo).name}: {e.get('status')} since {e.get('at')}, {e.get('why')}")
    needs = [(r, e) for r, e in aiw_sync_state()["targets"].items() if e.get("status") in ("failed", "changed", "blocked")]
    if needs:
        print("\naiw updates needing a look:")
        for repo, e in needs:
            print(f"    {Path(repo).name}: {e.get('status')} since {e.get('at')}, {e.get('why')}")


# --- aiw sync --------------------------------------------------------------------
# Every project with an installed aiw copy runs the version it was installed at until
# someone reruns the updater there. After each deploy pass, every project Claude Code has
# worked in whose copy is gitignored is updated from the merged aiw checkout. A project
# that commits its copy is never touched: an update there is a change to review.

WORKFLOW_FILE = "ai-workflow.md"
GITIGNORE_BLOCK = "# >>> ai-workflow (vendored, managed by installer) >>>"


def aiw_sync_state():
    try:
        d = json.loads(AIW_SYNC_STATE.read_text())
    except (OSError, ValueError):
        d = {}
    d = d if isinstance(d, dict) else {}
    d.setdefault("scanned", 0)
    d.setdefault("known", [])
    d.setdefault("targets", {})
    d.setdefault("last_session", {})
    return d


def workflow_version(repo):
    try:
        for line in (Path(repo) / WORKFLOW_FILE).read_text(errors="replace").splitlines():
            if line.startswith("Version:"):
                return line.split()[1] if len(line.split()) > 1 else None
    except OSError:
        pass
    return None


def version_key(v):
    return tuple(int(p) if p.isdigit() else 0 for p in (v or "").split("."))


def aiw_source():
    """The listed aiw checkout, only while it is on its default branch with nothing uncommitted."""
    for repo in deploy_projects():
        r = Path(repo)
        if not ((r / "install-manifest.json").is_file() and (r / "scripts" / "update.sh").is_file()):
            continue
        try:
            default = sh(["git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD"], cwd=repo).strip()
            branch = sh(["git", "branch", "--show-current"], cwd=repo).strip()
            dirty = sh(["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo).strip()
            ahead = int(sh(["git", "rev-list", "--count", f"{default}..HEAD"], cwd=repo).strip() or 0)
        except (RuntimeError, OSError, subprocess.TimeoutExpired, ValueError):
            return None
        # Off its default branch, with local edits, or with commits the remote lacks, the
        # checkout holds unmerged work.
        return repo if f"origin/{branch}" == default and not dirty and not ahead else None
    return None


def scan_sessions(state):
    """Add the main checkout of every session newer than the last scan to the known repos."""
    known, newest, tops = set(state["known"]), state["scanned"], {}
    for f in PROJECTS.glob("*/*.jsonl"):
        try:
            mtime = f.stat().st_mtime
        except OSError:
            continue
        if mtime <= state["scanned"]:
            continue
        newest = max(newest, mtime)
        cwd, _ = session_origin(f)
        if cwd and cwd not in tops:
            tops[cwd] = main_checkout(cwd) if Path(cwd).is_dir() else None
        if cwd and tops[cwd]:
            known.add(tops[cwd])
            last = state["last_session"]
            last[tops[cwd]] = max(last.get(tops[cwd], 0), int(mtime))
    state["known"], state["scanned"] = sorted(known), newest


def ignored_copy(repo):
    """True when the repo has an installer-managed aiw copy that git ignores."""
    r = Path(repo)
    try:
        if GITIGNORE_BLOCK not in (r / ".gitignore").read_text(errors="replace").splitlines():
            return False
    except OSError:
        return False
    if not (r / WORKFLOW_FILE).is_file():
        return False
    return subprocess.run(["git", "check-ignore", "-q", "--no-index", WORKFLOW_FILE], cwd=repo,
                          capture_output=True).returncode == 0 and subprocess.run(
        ["git", "ls-files", "--error-unmatch", WORKFLOW_FILE], cwd=repo, capture_output=True).returncode != 0


def aiw_paths(repo):
    """.gitignore and every path in the installer-managed block: what an update may write."""
    try:
        lines = (Path(repo) / ".gitignore").read_text(errors="replace").splitlines()
    except OSError:
        return [".gitignore"]
    paths, inside = [".gitignore"], False
    for line in lines:
        if line == GITIGNORE_BLOCK:
            inside = True
        elif line.startswith("# <<< ai-workflow"):
            inside = False
        elif inside and line.strip():
            paths.append(line.strip().rstrip("/"))
    return paths


def git_status(repo, paths, untracked="all"):
    return sh(["git", "status", "--porcelain", f"--untracked-files={untracked}", "--", *paths], cwd=repo).splitlines()


def run_update(source, repo):
    """update.sh in its own process group, so a timeout stops install.sh with it."""
    p = subprocess.Popen([str(Path(source) / "scripts" / "update.sh"), "--target", repo, "--source", source],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
    try:
        out, err = p.communicate(timeout=AIW_UPDATE_TIMEOUT)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        p.communicate()
        raise
    return p.returncode, out, err


def update_one(repo, source, prev, mark):
    """Returns (status, detail): updated, current, blocked, changed, or failed.

    `mark` is called just before update.sh starts, so a pass cut off mid-update is seen
    by the next one and the update run again: the version line is copied first, and on
    its own would read as current.
    """
    have, want = workflow_version(repo), workflow_version(source)
    try:
        if prev.get("status") == "changed" and git_status(repo, prev.get("files") or ["."]):
            return "changed", {"why": prev.get("why"), "files": prev.get("files")}
        if prev.get("status") != "updating" and (not have or not want or version_key(have) >= version_key(want)):
            return "current", {}
        paths = aiw_paths(repo)
        dirty = git_status(repo, paths, untracked="no")
        if dirty:
            files = sorted({l[3:] for l in dirty})
            return "blocked", {"why": f"uncommitted edits to aiw files git tracks hold the update to {want}: "
                                      + ", ".join(files)[:200]}
        mark()
        code, out, err = run_update(source, repo)
        after = git_status(repo, paths)
    except subprocess.TimeoutExpired:
        return "failed", {"why": f"update.sh timed out going {have} -> {want}"}
    except (RuntimeError, OSError) as e:
        return "failed", {"why": str(e).splitlines()[0] if str(e) else type(e).__name__}
    if code != 0:
        tail = (err or out).strip().splitlines()
        return "failed", {"why": f"update.sh exited {code} going {have} -> {want}"
                          + (f": {tail[-1][:200]}" if tail else "")}
    detail = {"from": have, "to": workflow_version(repo)}
    notes = [l.strip() for l in out.splitlines() if l.strip().startswith(("note:", "removed"))
             or "added new setting" in l or "did not add setting" in l]
    if notes:
        detail["notes"] = notes[:20]
    if after:
        files = sorted({l[3:] for l in after})
        return "changed", {**detail, "files": files,
                           "why": f"update to {detail['to']} changed files git tracks, to commit: {', '.join(files)[:200]}"}
    return "updated", detail


def sync_aiw():
    source = aiw_source()
    if not source:
        return
    state = aiw_sync_state()
    scan_sessions(state)
    t = now()
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(t))
    old, targets = state["targets"], {}
    state["targets"] = targets
    src = os.path.realpath(source)
    for repo in state["known"]:
        prev = old.get(repo, {})
        if os.path.realpath(repo) == src:
            continue
        # A session working here now may be running a hook or script the update would
        # rewrite under it; a project that only looks ineligible for one pass (mid-rebase,
        # on a branch without the block) keeps what was waiting on it.
        if t - state["last_session"].get(repo, 0) < ACTIVE_SECONDS or not ignored_copy(repo):
            if prev and Path(repo).is_dir():
                targets[repo] = prev
            continue

        def mark(repo=repo, prev=prev):
            targets[repo] = {**prev, "status": "updating", "at": stamp}
            write_json(AIW_SYNC_STATE, state)

        status, detail = update_one(repo, source, prev, mark)
        if status == "updated" and prev.get("status") == "updating":
            prev = {k: v for k, v in prev.items() if k != "status"}
        changed = status != prev.get("status") or detail.get("why") != prev.get("why")
        entry = {"status": status, "at": stamp if changed else prev.get("at", stamp)}
        for k in ("why", "files"):
            if k in detail:
                entry[k] = detail[k]
        # First sight of an up-to-date project is not news; every other change is.
        if status == "updated" or (changed and (prev or status != "current")):
            with open(DEPLOY_LOG, "a") as fh:
                fh.write(json.dumps({"at": stamp, "repo": repo, "aiw": status,
                                     **{k: v for k, v in detail.items() if k != "files"}}) + "\n")
        targets[repo] = entry
    write_json(AIW_SYNC_STATE, state)


def main(argv):
    if not argv or argv[0] not in ("run", "report", "deploy"):
        print(__doc__.strip().splitlines()[0])
        print("usage: scheduler.py run [--scheduled] [--dry-run] | report [N] | deploy")
        return 2
    {"run": cmd_run, "report": cmd_report, "deploy": cmd_deploy}[argv[0]](argv[1:])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
