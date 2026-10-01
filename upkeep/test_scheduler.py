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
T = int(time.mktime((2026, 10, 1, 22, 15, 0, 0, 0, -1)))  # a Thursday, 22:15 local


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
        rec, chosen = scheduler.decide(T + 3600, scheduled=True)  # 23:15
        self.assertIsNone(chosen)
        self.assertIn("outside the weekday 22:00 slot", rec["stopped"])

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


if __name__ == "__main__":
    unittest.main()
