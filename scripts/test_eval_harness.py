"""Offline test for the eval harness.

Run directly: `python3 scripts/test_eval_harness.py` (exits non-zero on failure).
Also invoked by scripts/repo-validation.sh. Calls no model: the arms and the
scorer are small scripts whose answers are fixed per case, so every expected
verdict here is known in advance. All inputs are test setup, not ground truth.
"""

import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "..", ".ai-policy", "eval", "harness.py")
sys.path.insert(0, os.path.dirname(HARNESS))
import harness  # noqa: E402

failures = []


def check(name, got, want):
    if got != want:
        failures.append(f"{name}: got {got!r}, want {want!r}")


def check_in(name, needle, haystack):
    if needle not in haystack:
        failures.append(f"{name}: {needle!r} not in output:\n{haystack}")


# An arm prints GOOD or BAD as the case says for that arm, and logs that it ran.
FAKE_ARM = """import json, sys
arm, input_file, counter = sys.argv[1:4]
case = json.load(open(input_file))
open(counter, "a").write(arm + "\\n")
print(case[arm].upper(), case.get("extra", ""))
"""
FAKE_SCORER = """import sys
print("pass" if "GOOD" in open(sys.argv[1]).read() else "fail")
"""
BROKEN_SCORER = 'print("pass")\n'


class Eval:
    """An eval directory with fake arms, under a home directory holding no instruction files."""

    def __init__(self, cases, scorer=FAKE_SCORER, **overrides):
        self.tmp = tempfile.mkdtemp(prefix="aiw-eval-test-")
        self.dir = os.path.join(self.tmp, "eval")
        self.home = os.path.join(self.tmp, "home")
        self.work = os.path.join(self.tmp, "work")
        self.counter = os.path.join(self.tmp, "ran.txt")
        for path in (self.dir, self.home, self.work, os.path.join(self.dir, "known")):
            os.makedirs(path)
        for name, body in (("arm.py", FAKE_ARM), ("scorer.py", scorer)):
            with open(os.path.join(self.tmp, name), "w") as f:
                f.write(body)
        known = []
        for i in range(5):
            for verdict, text in (("pass", "GOOD"), ("fail", "BAD")):
                rel = f"known/{verdict}-{i}.txt"
                with open(os.path.join(self.dir, rel), "w") as f:
                    f.write(text)
                known.append({"file": rel, "verdict": verdict})
        arm = [sys.executable, os.path.join(self.tmp, "arm.py")]
        self.spec = {
            "claim": "the new arm does the thing", "counted": "outputs that say GOOD",
            "human_confirmation": "yes, count that", "pass_example": "GOOD", "fail_example": "BAD",
            "cannot_show": ["anything about a real model"],
            "bar": {"alpha": 0.05, "negatives_max_regressions": 0},
            "arms": {"old": {"run": arm + ["old", "{input_file}", self.counter]},
                     "new": {"run": arm + ["new", "{input_file}", self.counter]}},
            "cases": [{"id": f"c{i}", "kind": kind, "input": json.dumps({"old": old, "new": new})}
                      for i, (kind, old, new) in enumerate(cases)],
            "scorer": {"cmd": [sys.executable, os.path.join(self.tmp, "scorer.py"), "{output_file}"]},
            "scorer_bar": {"fails_caught": 0.9, "passes_passed": 0.9},
            "known": known, "pilot_cases": 4, "est_cost_per_run_usd": 0.0,
        }
        self.spec.update(overrides)
        self.write()

    def write(self):
        with open(os.path.join(self.dir, "eval.json"), "w") as f:
            json.dump(self.spec, f)

    def gate(self, name, *options):
        done = subprocess.run([sys.executable, HARNESS, name, "--dir", self.dir, "--work-root", self.work, *options],
                              capture_output=True, text=True, env=dict(os.environ, HOME=self.home))
        return done.returncode, done.stdout + done.stderr

    def state(self):
        with open(os.path.join(self.dir, "state.json")) as f:
            return json.load(f)

    def review(self):
        with open(os.path.join(self.dir, "design-review.md"), "w") as f:
            f.write(f"Reviewed eval {self.state()['hash']}: no findings.\n")

    def runs(self):
        try:
            with open(self.counter) as f:
                return len(f.read().split())
        except OSError:
            return 0

    def pilot_runs(self):
        kinds = [c["kind"] for c in self.spec["cases"]]
        return min(4, kinds.count("target")) + kinds.count("negative") + 2

    def to_verdict(self):
        """Every gate in order, approving each spend, until one ends the eval."""
        self.gate("freeze")
        self.gate("context")
        self.gate("scorer")
        self.review()
        self.gate("pilot", "--approved-runs", str(self.pilot_runs()))
        self.gate("run", "--approved-runs", str(2 * len(self.spec["cases"])))
        self.gate("report")
        try:
            with open(os.path.join(self.dir, "report.json")) as f:
                return json.load(f)
        except OSError:
            return {"verdict": None}


def cases(target, n_target=12, negative=("bad", "bad"), n_negative=3):
    """GOOD is the counted behaviour. On a negative case it should be absent, so BAD is right there."""
    return [("negative", *negative)] * n_negative + [("target", *target)] * n_target


# --- the sign test, against values worked by hand in the standard way ---
check("six flips one way", harness.sign_test(6, 0), 2 * 0.5 ** 6)
check("five flips one way is not under 0.05", harness.sign_test(5, 0), 0.0625)
check("an even split is all luck", harness.sign_test(5, 5), 1.0)
check("46 against 37 is inside luck", round(harness.sign_test(46, 37), 2), 0.38)
check("flips needed at 0.05", harness.min_flips(0.05), 6)
check("settled early once new cannot lose", harness.settled(9, 0, 1, 0.05), harness.WORKS)
check("settled early once new cannot win", harness.settled(0, 0, 5, 0.05), harness.FAILS)
check("still open", harness.settled(3, 0, 9, 0.05), None)

# --- a planted effect is caught ---
e = Eval(cases(("bad", "good")))
report = e.to_verdict()

# --- the pilot prints what the models wrote, the new arm's first cases included ---
p = Eval(cases(("bad", "good")))
for g in ("freeze", "context", "scorer"):
    p.gate(g)
p.review()
code, out = p.gate("pilot", "--approved-runs", "9")
check_in("pilot prints an old output", "c3 (old arm): does not show it\n    BAD", out)
check_in("pilot prints a new output", "c3 (new arm): shows the behaviour\n    GOOD", out)
check("the new arm's pilot outputs are not counted", harness.tally(p.dir, p.spec)["pairs"], 0)
check("planted effect verdict", report["verdict"], harness.WORKS)
check("planted effect stops once settled", e.runs() < 9 + 2 * 15, True)

# --- old against old shows no effect, and stops once it cannot pass ---
e = Eval(cases(("bad", "bad")))
report = e.to_verdict()
check("old against old verdict", report["verdict"], harness.FAILS)
check("old against old flips", report["tally"]["new_wins"] + report["tally"]["old_wins"], 0)
check("old against old stops early", e.runs() < 9 + 2 * 15, True)
check("same arm twice is reported", report["tally"]["same_arm_cases"] > 0, True)

# --- a change that makes things worse does not pass ---
report = Eval(cases(("bad", "bad"), n_target=6) + [("target", "good", "bad")] * 6).to_verdict()
check("worse verdict", report["verdict"], harness.FAILS)
check("worse flips go toward old", report["tally"]["old_wins"] > 0, True)

# --- nothing for the new arm to fix: stops before the full run ---
e = Eval(cases(("good", "good")))
report = e.to_verdict()
check("ceiling verdict", report["verdict"], harness.UNTESTABLE)
check("ceiling spends only the pilot", e.runs(), 9)
check_in("ceiling reason", "nothing for the new arm to fix", report["reason"])

# --- a new arm that fires where it should not ---
report = Eval(cases(("bad", "good"), negative=("bad", "good"))).to_verdict()
check("over-fire verdict", report["verdict"], harness.FAILS)
check_in("over-fire reason", "fires where it should not", report["reason"])

# --- a negative case where the old arm already shows the behaviour is broken, caught in the pilot ---
e = Eval(cases(("bad", "good"), negative=("good", "good")))
report = e.to_verdict()
check("broken negative verdict", report["verdict"], harness.UNTESTABLE)
check_in("broken negative named", "c0", report["reason"])
check("broken negative spends only the pilot", e.runs(), 9)

# --- a scorer that passes everything is caught before any run ---
e = Eval(cases(("bad", "good")), scorer=BROKEN_SCORER)
report = e.to_verdict()
check("broken scorer verdict", report["verdict"], harness.UNTESTABLE)
check("broken scorer spends nothing", e.runs(), 0)

# --- gates cannot be skipped or reordered ---
e = Eval(cases(("bad", "good")))
code, out = e.gate("pilot", "--approved-runs", "9")
check("pilot before freeze refused", code, 1)
e.gate("freeze")
code, out = e.gate("scorer")
check("scorer before context refused", code, 1)
check_in("names the missing gate", "needs the context gate", out)
e.gate("context")
e.gate("scorer")
code, out = e.gate("pilot", "--approved-runs", "9")
check("pilot without a design review refused", code, 1)
check_in("asks for the review", "design review", out)
e.review()
code, out = e.gate("pilot")
check("pilot without the approved count refused", code, 1)
check_in("states the spend", "up to 9 runs", out)
check("nothing ran while refused", e.runs(), 0)

# --- changing the eval after freeze voids the gates ---
e.spec["bar"]["alpha"] = 0.2
e.write()
code, out = e.gate("pilot", "--approved-runs", "9")
check("changed eval refused", code, 1)
check_in("says why", "changed after freeze", out)
e.gate("freeze")
check("freezing again before any run is still version 1", e.state()["version"], 1)

# --- changing the eval after results exist is a new version, said in the report ---
e = Eval(cases(("bad", "bad")))
e.to_verdict()
e.spec["bar"]["alpha"] = 0.2
e.write()
code, out = e.gate("freeze")
check("refreeze after results refused", code, 1)
code, out = e.gate("freeze", "--new-version")
check("refreeze as a new version", code, 0)
check("the old report is archived with its runs", (os.path.exists(os.path.join(e.dir, "report.md")),
      os.path.exists(os.path.join(e.dir, "runs.v1", "report.md"))), (False, True))
check("version counted", e.state()["version"], 2)

# --- an eval that is not fully stated cannot be frozen ---
for label, change, message in (
    ("no bar", {"bar": {}}, "bar.alpha"),
    ("no human confirmation", {"human_confirmation": ""}, "human_confirmation"),
    ("no known answers", {"known": []}, "known"),
    ("nothing it cannot show", {"cannot_show": []}, "cannot_show"),
):
    code, out = Eval(cases(("bad", "good")), **change).gate("freeze")
    check(f"{label} refused", code, 1)
    check_in(f"{label} named", message, out)
code, out = Eval(cases(("bad", "good"), n_target=5)).gate("freeze")
check_in("too few cases to ever pass", "can never reach", out)
e = Eval(cases(("bad", "good")))
e.spec["cases"][0]["rule"] = "a second rule"
e.write()
code, out = e.gate("freeze")
check_in("a case with its own rule", "counts one thing", out)
code, out = Eval(cases(("bad", "good"), n_negative=0)).gate("freeze")
check_in("no negative case", "no negative case", out)

# --- the skeleton names every field, and cannot be frozen until it is filled in ---
d = tempfile.mkdtemp(prefix="aiw-eval-init-")
subprocess.run([sys.executable, HARNESS, "init", "--dir", d], capture_output=True)
done = subprocess.run([sys.executable, HARNESS, "freeze", "--dir", d], capture_output=True, text=True)
check("unfilled skeleton refused", done.returncode, 1)
check_in("says a TODO is left", "TODO", done.stderr)
with open(os.path.join(d, "eval.json")) as f:
    skeleton = json.load(f)
check("the skeleton has every field a working eval sets",
      sorted(set(Eval(cases(("bad", "good"))).spec) - set(skeleton)), [])

# --- instruction files above the run directory end the eval before any spend ---
e = Eval(cases(("bad", "good")))
with open(os.path.join(e.tmp, "CLAUDE.md"), "w") as f:
    f.write("be good\n")
e.gate("freeze")
e.gate("context")
check("leak verdict", e.state().get("verdict"), harness.UNTESTABLE)

# --- instruction files in the home directory must be accounted for ---
e = Eval(cases(("bad", "good")))
os.makedirs(os.path.join(e.home, ".claude"))
with open(os.path.join(e.home, ".claude", "CLAUDE.md"), "w") as f:
    f.write("be good\n")
e.gate("freeze")
code, out = e.gate("context")
check("home instructions refused", code, 1)
check_in("names the home file", ".claude/CLAUDE.md", out)
e.spec["home_instructions_excluded_by"] = "the arm passes --setting-sources project"
e.write()
e.gate("freeze")
code, out = e.gate("context")
check("home instructions accounted for", code, 0)

# --- a finished run is never repeated ---
e = Eval(cases(("bad", "good")))
e.to_verdict()
ran = e.runs()
state = e.state()
del state["verdict"], state["gates"]["run"]
with open(os.path.join(e.dir, "state.json"), "w") as f:
    json.dump(state, f)
e.gate("run", "--approved-runs", str(2 * len(e.spec["cases"])))
check("resumed without rerunning", e.runs(), ran)

# --- private details are replaced before an output is saved ---
e = Eval(cases(("bad", "good")), private_patterns=["sekrit-\\d+"])
e.spec["cases"][3]["input"] = json.dumps({"old": "bad", "new": "good", "extra": f"sekrit-42 {e.home}/notes"})
e.write()
report = e.to_verdict()
with open(os.path.join(e.dir, "runs", "main", "c3", "new", "output.txt")) as f:
    saved = f.read()
check_in("pattern replaced", "[private]", saved)
check("pattern gone", "sekrit-42" in saved, False)
check("home path gone", e.home in saved, False)

# --- the human's name, read from their git identity, is replaced too ---
e = Eval(cases(("bad", "good")))
with open(os.path.join(e.home, ".gitconfig"), "w") as f:
    f.write("[user]\n\temail = zelda.quux@example.com\n\tname = zelda-ths\n")
e.spec["cases"][3]["input"] = json.dumps({"old": "bad", "new": "good", "extra": "Thanks, Zelda! zelda.quux@example.com"})
e.write()
e.to_verdict()
with open(os.path.join(e.dir, "runs", "main", "c3", "new", "output.txt")) as f:
    saved = f.read()
check("name gone", "zelda" in saved.lower(), False)
check_in("name replaced", "[name]", saved)
check("replacements counted", report["redactions"] > 0, True)

# --- the scorer never learns which arm wrote an output ---
e = Eval(cases(("bad", "good")), scorer="import sys\nopen(sys.argv[2], 'a').write(' '.join(sys.argv) + '\\n')\n"
         "print('pass' if 'GOOD' in open(sys.argv[1]).read() else 'fail')\n")
seen = os.path.join(e.tmp, "scorer-saw.txt")
e.spec["scorer"]["cmd"].append(seen)
e.write()
e.to_verdict()
with open(seen) as f:
    paths = [line.split()[1] for line in f]
check("scorer paths name no arm", any("/old/" in p or "/new/" in p for p in paths), False)

# --- outputs the judges split on reach the human only when the verdict turns on them ---
# This scorer stands in for a panel: on MAYBE it reports a split, with the majority saying pass.
SPLIT_SCORER = """import sys
text = open(sys.argv[1]).read()
if "MAYBE" in text:
    print("SPLIT")
print("pass" if "GOOD" in text or "MAYBE" in text else "fail")
"""
e = Eval(cases(("bad", "good")) + [("target", "bad", "maybe")], scorer=SPLIT_SCORER)
report = e.to_verdict()
check("a split that cannot change the verdict asks nobody", report["verdict"], harness.WORKS)
check("no ruling awaited", e.state().get("awaiting"), None)

for ruling, want in (("pass", harness.WORKS), ("fail", harness.FAILS)):
    e = Eval(cases(("bad", "good"), n_target=5) + [("target", "bad", "maybe")] + [("target", "bad", "bad")] * 2,
             scorer=SPLIT_SCORER)
    report = e.to_verdict()
    check("a split the verdict turns on gives no verdict yet", report["verdict"], None)
    awaited = e.state()["awaiting"]
    check("one output awaits a ruling", len(awaited), 1)
    sid = next(iter(awaited))
    check("the file shown to the human names no arm", sorted(os.listdir(os.path.join(e.dir, "splits"))), [f"{sid}.txt"])
    code, out = e.gate("report")
    check("no report before the ruling", code, 1)
    e.gate("rule", "--id", sid, "--verdict", ruling)
    e.gate("report")
    with open(os.path.join(e.dir, "report.json")) as f:
        report = json.load(f)
    check(f"ruled {ruling}", report["verdict"], want)

# Two early splits leave the verdict open when the run could stop on the majority score alone.
# The run goes on to the last case instead, which settles it without asking anyone.
e = Eval(cases(("bad", "maybe"), n_target=2) + [("target", "bad", "good")] * 8, scorer=SPLIT_SCORER)
report = e.to_verdict()
check("remaining cases are run before the human is asked", report["verdict"], harness.WORKS)
check("no ruling awaited after running on", e.state().get("awaiting"), None)
check("every case was run", e.state()["gates"]["run"]["cases_run"], 13)

e = Eval(cases(("bad", "maybe"), n_target=8), scorer=SPLIT_SCORER)
report = e.to_verdict()
check("too many decisive splits", report["verdict"], harness.UNTESTABLE)
check_in("says the rule is too loose", "too loose to judge", report["reason"])

# --- the judge panel: majority verdict, splits flagged, each judge sealed ---
JUDGES = os.path.join(os.path.dirname(HARNESS), "judges.py")
tmp = tempfile.mkdtemp(prefix="aiw-judges-test-")
STRICT = "import sys\nprint('reasoning...')\nprint('**PASS**' if 'GOOD' in sys.stdin.read().split('<output>')[1] else 'FAIL.')\n"
LENIENT = "import sys\nsys.stdin.read()\nprint('PASS')\n"
SILENT = "import sys\nsys.stdin.read()\nprint('I cannot decide')\n"
BY_RULE = "import sys\nprint('PASS' if 'special-rule' in sys.stdin.read() else 'FAIL')\n"
RECORDER = f"import sys\nopen({os.path.join(tmp, 'saw.txt')!r}, 'w').write(sys.stdin.read())\nprint('PASS')\n"


def judge(output, panel, case=None):
    """Run the panel on one output; returns (exit code, stdout lines, last log row)."""
    paths = {}
    for name, body in (("rule.txt", "the output says GOOD"), ("out.txt", output), ("case.json", json.dumps(case or {}))):
        paths[name] = os.path.join(tmp, name)
        with open(paths[name], "w") as f:
            f.write(body)
    members = []
    for i, body in enumerate(panel):
        script = os.path.join(tmp, f"judge{i}.py")
        with open(script, "w") as f:
            f.write(body)
        members.append({"name": f"j{i}", "provider": f"p{i}", "cmd": [sys.executable, script]})
    with open(os.path.join(tmp, "panel.json"), "w") as f:
        json.dump(members, f)
    log = os.path.join(tmp, "log.jsonl")
    done = subprocess.run([sys.executable, JUDGES, "--rule-file", paths["rule.txt"], "--output-file", paths["out.txt"],
                           "--case-file", paths["case.json"], "--log", log, "--panel", os.path.join(tmp, "panel.json")],
                          capture_output=True, text=True, env=dict(os.environ, AIW_EVAL_JUDGE_RETRY_WAITS="0 0 0"))
    with open(log) as f:
        row = json.loads(f.read().splitlines()[-1])
    return done.returncode, done.stdout.split(), row


code, out, row = judge("GOOD", [STRICT, STRICT, STRICT])
check("judges agree on a pass", out, ["pass"])
check("every vote is logged", [v["vote"] for v in row["votes"]], ["pass"] * 3)
code, out, row = judge("BAD", [STRICT, STRICT, LENIENT])
check("a lenient judge is outvoted and the split flagged", out, ["SPLIT", "fail"])
code, out, row = judge("BAD", [STRICT, LENIENT])
check("a tie counts as fail", out, ["SPLIT", "fail"])
code, out, row = judge("GOOD", [STRICT, STRICT, SILENT])
check("two answers are enough", out, ["pass"])
code, out, row = judge("GOOD", [STRICT, SILENT, SILENT])
check("one answer is no verdict", (code, out), (1, []))
code, out, row = judge("x", [BY_RULE] * 3, case={"id": "neg1", "rule": "special-rule: says nothing"})
check("every output is judged against the one rule", out, ["fail"])
judge("GOOD", [RECORDER, STRICT, STRICT], case={"id": "case-zebra", "kind": "target"})
with open(os.path.join(tmp, "saw.txt")) as f:
    saw = f.read()
check("a judge is not shown the case", "case-zebra" in saw, False)
# A judge turned away on its first try answers on its second.
FLAKY = (f"import os, sys\nsys.stdin.read()\nflag = {os.path.join(tmp, 'tried')!r}\n"
         "if os.path.exists(flag):\n    print('PASS')\nelse:\n    open(flag, 'w').close()\n    sys.exit('429 Too Many Requests')\n")
code, out, row = judge("GOOD", [FLAKY, STRICT, STRICT])
check("a judge turned away is tried again", [v["vote"] for v in row["votes"]], ["pass"] * 3)
check_in("a judge is shown the rule", "the output says GOOD", saw)

# --- a judge too unsure to vote abstains: no vote, no split, no second try ---
ABSTAINER = (f"import sys\nsys.stdin.read()\nopen({os.path.join(tmp, 'abstained')!r}, 'a').write('x')\n"
             "print('ABSTAIN')\n")
code, out, row = judge("GOOD", [ABSTAINER, STRICT, STRICT])
check("an abstention is not a split", out, ["pass"])
with open(os.path.join(tmp, "abstained")) as f:
    check("an abstaining judge is asked once", f.read(), "x")
sys.path.insert(0, os.path.dirname(HARNESS))
import jev_vote  # noqa: E402
check("Jev votes when sure", jev_vote.vote_from({"lean": "pass", "probabilities": {"pass": 0.9, "fail": 0.1}}).split()[-1], "PASS")
check("Jev abstains near a coin toss", jev_vote.vote_from({"lean": "pass", "probabilities": {"pass": 0.52, "fail": 0.48}}).split()[-1], "ABSTAIN")

# --- the Jev seat refuses a prompt it cannot split into rule and output (no network touched) ---
done = subprocess.run([sys.executable, os.path.join(os.path.dirname(HARNESS), "jev_vote.py")],
                      input="no tags here", capture_output=True, text=True)
check("jev seat without rule and output", done.returncode, 2)

# --- the shipped panel names judges from three different providers ---
with open(os.path.join(os.path.dirname(HARNESS), "panel.json")) as f:
    check("three providers", len({j["provider"] for j in json.load(f)}), 3)

if failures:
    print("eval harness test: FAILED")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)
print("eval harness test: OK")
