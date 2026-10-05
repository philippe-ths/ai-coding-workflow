"""Quota gates and the scheduled-slot gate, against a sandbox state dir."""
import calendar
import json
import os
import tempfile
import time
import unittest

STATE = tempfile.mkdtemp()
os.environ["AIW_UPKEEP_HOME"] = STATE
import scheduler  # noqa: E402

DAY = 86400
T = int(time.mktime((2026, 10, 1, 22, 0, 30, 0, 0, -1)))  # a Thursday, 22:00:30 local


def snapshot(week_used, five_used, saved=T - 3600, week_resets=T + 3 * DAY, five_resets=T + 3600):
    with open(os.path.join(STATE, "quota.json"), "w") as fh:
        json.dump({"saved_at": saved, "rate_limits": {
            "seven_day": {"used_percentage": week_used, "resets_at": week_resets},
            "five_hour": {"used_percentage": five_used, "resets_at": five_resets}}}, fh)


class QuotaGates(unittest.TestCase):
    def test_no_snapshot_fails(self):
        try:
            os.remove(os.path.join(STATE, "quota.json"))
        except FileNotFoundError:
            pass
        self.assertEqual(scheduler.quota_gates(T), (False, {"reason": "no usable quota snapshot"}))

    def test_snapshot_with_a_null_field_fails_without_crashing(self):
        snapshot(week_used=None, five_used=10)
        self.assertEqual(scheduler.quota_gates(T), (False, {"reason": "no usable quota snapshot"}))

    def test_under_pace_with_room_passes(self):
        snapshot(week_used=50, five_used=20)  # 4 days elapsed: pace 57.1
        self.assertTrue(scheduler.quota_gates(T)[0])

    def test_ahead_of_pace_fails(self):
        snapshot(week_used=60, five_used=20)
        ok, d = scheduler.quota_gates(T)
        self.assertFalse(ok)
        self.assertEqual(d["reason"], "weekly use is ahead of pace")

    def test_full_session_window_fails_until_it_resets(self):
        snapshot(week_used=10, five_used=70)
        self.assertFalse(scheduler.quota_gates(T)[0])
        snapshot(week_used=10, five_used=70, five_resets=T - 60)
        self.assertTrue(scheduler.quota_gates(T)[0])

    def test_snapshot_from_previous_week_fails(self):
        snapshot(week_used=0, five_used=0, saved=T - 5 * DAY)
        self.assertFalse(scheduler.quota_gates(T)[0])


class ScheduledSlot(unittest.TestCase):
    def test_missed_night_is_skipped(self):
        rec, chosen = scheduler.decide(T + 3600, scheduled=True)  # 23:00
        self.assertIsNone(chosen)
        self.assertIn("night is skipped", rec["stopped"])

    def test_a_late_start_means_the_machine_was_asleep_at_22(self):
        rec, chosen = scheduler.decide(T + 89, scheduled=True)  # 22:01:59, as on 2026-10-02
        self.assertIsNone(chosen)
        self.assertIn("asleep then", rec["stopped"])

    def test_weekend_is_skipped(self):
        rec, chosen = scheduler.decide(T + 2 * DAY, scheduled=True)  # Saturday
        self.assertIsNone(chosen)


class Candidates(unittest.TestCase):
    def test_iso_dates_are_utc_in_summer_and_winter(self):
        self.assertEqual(scheduler.iso_epoch("2026-07-01T00:00:00Z"), 1782864000)
        self.assertEqual(scheduler.iso_epoch("2026-12-01T00:00:00Z"), 1796083200)

    def test_sdk_sessions_are_not_the_human_working(self):
        d = tempfile.mkdtemp()
        for name, entry in (("human.jsonl", "cli"), ("desktop.jsonl", "claude-desktop"), ("bot.jsonl", "sdk-cli")):
            with open(os.path.join(d, name), "w") as fh:
                fh.write(json.dumps({"cwd": "/x", "entrypoint": entry}) + "\n")
        origins = {n: scheduler.session_origin(os.path.join(d, n))[1] for n in os.listdir(d)}
        counted = {n for n, e in origins.items() if e and not e.startswith("sdk")}
        self.assertEqual(counted, {"human.jsonl", "desktop.jsonl"})

    def test_ranking_counts_only_issues_upkeep_would_pick(self):
        repo = tempfile.mkdtemp()
        os.makedirs(os.path.join(repo, ".claude", "skills", "aiw-upkeep"))
        open(os.path.join(repo, "ai-workflow.md"), "w").close()
        open(os.path.join(repo, ".claude", "skills", "aiw-upkeep", "SKILL.md"), "w").close()
        day0 = "2026-09-21T22:15:00Z"
        issue = lambda n, labels=(), prs=(): {"number": n, "createdAt": day0,
                                             "labels": [{"name": l} for l in ("aiw:upkeep",) + labels],
                                             "closedByPullRequestsReferences": list(prs)}
        replies = {
            "pr list --state open": [],
            "issue list": [issue(1), issue(2, ("aiw:direction",)), issue(3, prs=[{"number": 9}]), issue(4)],
            "pr list --state closed": [{"mergedAt": None, "closingIssuesReferences": [{"number": 4}]}],
        }
        def fake_gh(_repo, args):
            return next(v for k, v in replies.items() if " ".join(args).startswith(k))
        real_gh, real_sh = scheduler.gh_json, scheduler.sh
        scheduler.gh_json, scheduler.sh = fake_gh, lambda *a, **k: ""
        try:
            got = scheduler.assess(repo, calendar.timegm((2026, 10, 1, 22, 15, 0)))
        finally:
            scheduler.gh_json, scheduler.sh = real_gh, real_sh
        self.assertEqual(got, {"issues": 1, "issue_days": 10.0})


class StopReasons(unittest.TestCase):
    def test_a_project_in_use_is_skipped(self):
        snapshot(week_used=10, five_used=10)
        repo = tempfile.mkdtemp()
        open(os.path.join(repo, "ai-workflow.md"), "w").close()
        real = (scheduler.recent_repos, scheduler.side_findings)
        scheduler.recent_repos = lambda t: {repo: t - 60}
        scheduler.side_findings = lambda r: {}
        try:
            rec, chosen = scheduler.decide(T, scheduled=True)
        finally:
            scheduler.recent_repos, scheduler.side_findings = real
        self.assertIsNone(chosen)
        self.assertIn("in use", rec["skipped"][repo])

    def test_unreachable_github_is_not_reported_as_an_empty_queue(self):
        snapshot(week_used=10, five_used=10)
        real = (scheduler.recent_repos, scheduler.assess, scheduler.side_findings)
        repo = tempfile.mkdtemp()
        open(os.path.join(repo, "ai-workflow.md"), "w").close()
        scheduler.recent_repos = lambda t: {repo: t - 3600}
        scheduler.assess = lambda r, t: {"skip": "could not read GitHub: gh pr list: error connecting to api.github.com"}
        scheduler.side_findings = lambda r: None
        try:
            rec, chosen = scheduler.decide(T, scheduled=True)
        finally:
            scheduler.recent_repos, scheduler.assess, scheduler.side_findings = real
        self.assertIsNone(chosen)
        self.assertEqual(rec["stopped"], "could not read GitHub for 1 project(s)")
        self.assertNotIn("findings", rec)

    def test_a_multi_line_gh_error_is_logged_on_one_line(self):
        repo = tempfile.mkdtemp()
        os.makedirs(os.path.join(repo, ".claude", "skills", "aiw-upkeep"))
        open(os.path.join(repo, "ai-workflow.md"), "w").close()
        open(os.path.join(repo, ".claude", "skills", "aiw-upkeep", "SKILL.md"), "w").close()
        def offline(*a, **k):
            raise RuntimeError("gh pr list: error connecting to api.github.com\ncheck your internet connection")
        real = scheduler.sh
        scheduler.sh = offline
        try:
            got = scheduler.assess(repo, T)
        finally:
            scheduler.sh = real
        self.assertNotIn("\n", got["skip"])


MODE_SH = """#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
echo "$1" >> .claude/calls
[ -f .claude/fail-$1 ] && exit 1
[ -f .claude/dirty-$1 ] && touch stray.bak
if [ "$1" = build ]; then mv .claude/skills-off/aiw-upkeep .claude/skills/aiw-upkeep; fi
if [ "$1" = work ]; then mv .claude/skills/aiw-upkeep .claude/skills-off/aiw-upkeep; fi
echo "$1" > .claude/mode
"""


def work_mode_project():
    repo = tempfile.mkdtemp()
    for d in (".claude/skills", ".claude/skills-off/aiw-upkeep", "scripts"):
        os.makedirs(os.path.join(repo, d))
    open(os.path.join(repo, ".claude/skills-off/aiw-upkeep/SKILL.md"), "w").close()
    with open(os.path.join(repo, ".claude/mode"), "w") as fh:
        fh.write("work\n")
    with open(os.path.join(repo, "scripts/mode.sh"), "w") as fh:
        fh.write(MODE_SH)
    os.chmod(os.path.join(repo, "scripts/mode.sh"), 0o755)
    with open(os.path.join(repo, ".gitignore"), "w") as fh:
        fh.write(".claude/\n")
    import subprocess
    for cmd in (["git", "init", "-q", "-b", "main"], ["git", "add", "-A"],
                ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init"]):
        subprocess.run(cmd, cwd=repo, check=True)
    return repo


def read(repo, name):
    with open(os.path.join(repo, name)) as fh:
        return fh.read().split()


class WorkMode(unittest.TestCase):
    def setUp(self):
        scheduler.PENDING.unlink(missing_ok=True)

    def test_a_parked_project_is_recognised(self):
        self.assertTrue(scheduler.in_work_mode(work_mode_project()))

    def test_the_run_happens_in_build_and_work_mode_is_restored(self):
        repo = work_mode_project()
        seen = {}
        def run():
            seen["mode"] = read(repo, ".claude/mode")[0]
            return {"outcome": "finished"}
        out = scheduler.run_in_build_mode(repo, run, {})
        self.assertEqual(seen["mode"], "build")
        self.assertEqual(read(repo, ".claude/calls"), ["build", "work"])
        self.assertEqual(read(repo, ".claude/mode"), ["work"])
        self.assertNotIn("mode_restore", out)
        self.assertNotIn("tree_changed", out)
        self.assertFalse(scheduler.PENDING.exists())

    def test_work_mode_is_restored_and_logged_when_the_run_crashes(self):
        repo = work_mode_project()
        def run():
            raise RuntimeError("boom")
        out = scheduler.run_in_build_mode(repo, run, {})
        self.assertEqual(read(repo, ".claude/mode"), ["work"])
        self.assertIn("boom", out["outcome"])

    def test_a_killed_run_is_repaired_by_the_next_invocation(self):
        repo = work_mode_project()
        scheduler.switch_mode(repo, "build")
        scheduler.set_pending(repo, True)
        self.assertEqual(scheduler.repair_pending({}, T), [{"repo": repo, "restored": True}])
        self.assertEqual(read(repo, ".claude/mode"), ["work"])
        self.assertEqual(scheduler.pending(), [])

    def test_a_repair_sees_through_a_marker_written_last(self):
        repo = work_mode_project()
        scheduler.switch_mode(repo, "build")
        with open(os.path.join(repo, ".claude/mode"), "w") as fh:
            fh.write("work\n")  # killed after the skills moved, before the marker was written
        scheduler.set_pending(repo, True)
        self.assertEqual(scheduler.repair_pending({}, T)[0].get("restored"), True)
        self.assertTrue(os.path.isfile(os.path.join(repo, ".claude/skills-off/aiw-upkeep/SKILL.md")))

    def test_a_repair_waits_while_the_project_is_in_use(self):
        repo = work_mode_project()
        scheduler.switch_mode(repo, "build")
        scheduler.set_pending(repo, True)
        got = scheduler.repair_pending({repo: T - 60}, T)
        self.assertIn("in use", got[0]["error"])
        self.assertEqual(read(repo, ".claude/mode"), ["build"])
        self.assertEqual(scheduler.pending(), [repo])
        scheduler.set_pending(repo, False)

    def test_one_pending_repair_does_not_overwrite_another(self):
        scheduler.set_pending("/x", True)
        scheduler.set_pending("/y", True)
        self.assertEqual(scheduler.pending(), ["/x", "/y"])
        scheduler.set_pending("/x", False)
        scheduler.set_pending("/y", False)
        self.assertFalse(scheduler.PENDING.exists())

    def test_sigterm_mid_run_still_restores_work_mode(self):
        repo = work_mode_project()
        code = (
            "import os, signal, sys\n"
            f"sys.path.insert(0, {os.path.dirname(os.path.abspath(scheduler.__file__))!r})\n"
            "import scheduler\n"
            "signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))\n"
            "result = {}\n"
            f"scheduler.run_in_build_mode({repo!r}, lambda: os.kill(os.getpid(), signal.SIGTERM) or {{}}, result)\n"
        )
        import subprocess, sys as _sys
        p = subprocess.run([_sys.executable, "-c", code], env={**os.environ, "AIW_UPKEEP_HOME": tempfile.mkdtemp()})
        self.assertEqual(p.returncode, 143)
        self.assertEqual(read(repo, ".claude/calls"), ["build", "work"])
        self.assertEqual(read(repo, ".claude/mode"), ["work"])

    def test_a_switch_that_dirties_the_tree_means_no_run(self):
        repo = work_mode_project()
        open(os.path.join(repo, ".claude/dirty-build"), "w").close()
        ran = []
        out = scheduler.run_in_build_mode(repo, lambda: ran.append(1) or {}, {})
        self.assertEqual(ran, [])
        self.assertIn("changed the tree", out["mode_switch"])
        self.assertEqual(read(repo, ".claude/mode"), ["work"])

    def test_a_run_that_leaves_the_tree_changed_is_reported(self):
        repo = work_mode_project()
        def run():
            open(os.path.join(repo, "left-behind.txt"), "w").close()
            return {"outcome": "finished"}
        out = scheduler.run_in_build_mode(repo, run, {})
        self.assertIn("left-behind.txt", out["tree_changed"])

    def test_a_half_switched_project_is_still_flipped(self):
        repo = work_mode_project()
        os.rename(os.path.join(repo, ".claude/skills-off/aiw-upkeep"), os.path.join(repo, ".claude/skills/aiw-upkeep"))
        self.assertTrue(scheduler.in_work_mode(repo))

    def test_a_failed_switch_to_build_means_no_run(self):
        repo = work_mode_project()
        open(os.path.join(repo, ".claude/fail-build"), "w").close()
        ran = []
        out = scheduler.run_in_build_mode(repo, lambda: ran.append(1) or {}, {})
        self.assertEqual(ran, [])
        self.assertEqual(out["outcome"], "not run")
        self.assertIn("mode.sh build failed", out["mode_switch"])

    def test_a_failed_return_to_work_is_reported(self):
        repo = work_mode_project()
        open(os.path.join(repo, ".claude/fail-work"), "w").close()
        out = scheduler.run_in_build_mode(repo, lambda: {"outcome": "finished"}, {})
        self.assertIn("mode.sh work failed", out["mode_restore"])
        self.assertEqual(scheduler.pending(), [repo])
        scheduler.set_pending(repo, False)


if __name__ == "__main__":
    unittest.main()
