"""Run a behavioural eval of one change, old against new, through gates that cannot be skipped.

Usage:
  python3 .ai-policy/eval/harness.py <gate> --dir <eval directory> [options]

The eval directory holds `eval.json`, written before any run, and everything the
harness saves. Gates run in this order, cheapest first, and each refuses until
the one before it has passed for the same `eval.json`:

  init      write a skeleton eval.json naming every field
  freeze    check the eval is fully stated (claim, bar, cases, scorer) and lock it
  context   check no instruction file leaks into a run from the directories above it
  scorer    measure the scorer on known answers, both ways
  pilot     run the old arm on a few cases: is there anything for the new arm to fix?
            Prints every output it made, the new arm's first two included, to be read
  run       run both arms on every case, stopping once the result is settled
  rule      record the human's pass or fail on an output the judges split on
  report    write report.md and report.json

The scorer answers one question of every output: does it show the counted
behaviour? A target case passes when it does; a negative case, where the change
should not fire, passes when it does not.

Every eval ends in one of three verdicts: "works", "does not work", or "cannot be
tested this way". The last is found as early as it can be: by freeze or context at
no cost, by the scorer gate for a few scorer calls, by the pilot for a handful of
runs. Two causes can only show in the full run: too many runs erroring, and the
judges splitting on more outputs than the human will be asked about.

Freeze locks eval.json, the files in the eval directory, the files the commands
name, and the harness itself. A file a command writes to must end .log or .jsonl,
which are left out. Changing one afterwards voids
every gate, and freezing again once any gate has measured something is a new
version, which the report states. A new arm changed after its results were seen is
refused until it is given cases it has not been run on.

An arm's `run` command is run in a fresh empty directory with its stdout saved as
the output; `setup`, if given, runs there first. Commands may use {input_file},
{workdir}, {case_id} and {eval_dir}; the scorer's may use {output_file},
{case_file} and {eval_dir}. `text_under_test` lists files holding the changed
text, so freeze can show which cases share its distinctive words.

`pilot` and `run` print how many runs they will make, what that costs, and how long
it takes (from `est_seconds_per_run`, then from the pilot's own timings), and need
`--approved-runs N` to match, so the number is said before it is spent.

Exit codes: 0 the gate passed or a verdict was written, 1 the gate refused or
failed, 2 usage error.
"""

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

GATES = ["freeze", "context", "scorer", "pilot", "run"]
WORKS, FAILS, UNTESTABLE = "works", "does not work", "cannot be tested this way"
MIN_KNOWN = 5
MAX_ALPHA = 0.1  # a looser line than this calls luck real too often to be a bar
MIN_SCORER_BAR = 0.7
MAX_ERROR_SHARE = 0.1
MIN_PILOT_CASES = 4  # fewer and one lucky case decides whether the eval goes ahead
REHEARSAL_CASES = 2  # target cases the pilot also runs on the new arm, to be read, never counted
PILOT_PRINT_CHARS = 400
MAX_RULINGS = 5  # the most outputs the human is ever asked to rule on
# Files an agent reads as instructions. One above a run directory reaches every run.
INSTRUCTION_FILES = [
    "CLAUDE.md", "AGENTS.md", "GEMINI.md", "ai-workflow.md", ".claude", ".agents",
    ".codex", ".github/copilot-instructions.md", ".cursorrules",
]
# Files an agent loads from the home directory wherever it runs.
GLOBAL_INSTRUCTION_FILES = [".claude/CLAUDE.md", ".codex/AGENTS.md", ".gemini/GEMINI.md", ".aiw/preferences.md"]


class Refused(Exception):
    """The gate cannot go ahead; the message says what is missing."""


def sign_test(a, b):
    """Two-sided exact sign test: how often luck alone splits a+b flips this unevenly."""
    n = a + b
    if n == 0:
        return 1.0
    tail = sum(math.comb(n, i) for i in range(min(a, b) + 1)) / 2 ** n
    return min(1.0, 2 * tail)


def min_flips(alpha):
    """Fewest flips, all one way, that the sign test can call real at this line."""
    k = 1
    while sign_test(k, 0) >= alpha:
        k += 1
    return k


def settled(new_wins, old_wins, remaining, alpha):
    """The verdict on the target cases once no remaining case can change it, else None."""
    def passes(n, o):
        return n > o and sign_test(n, o) < alpha
    if passes(new_wins, old_wins + remaining):
        return WORKS
    if not passes(new_wins + remaining, old_wins):
        return FAILS
    return None


# --- eval directory -----------------------------------------------------------

# What the harness itself writes into the eval directory. Everything else there is part of the eval.
OWN_FILES = ("state.json", "report.md", "report.json", "design-review.md")
OWN_DIRS = ("splits", "__pycache__")
OWN_SUFFIXES = (".jsonl", ".log", ".tmp")


def files_named(cmd, d):
    """Existing files a command names, as a whole argument or as a word inside a shell string."""
    found = set()
    for part in cmd if isinstance(cmd, list) else []:
        text = str(part).replace("{eval_dir}", d)
        for word in [text] + re.split(r"[\s'\"=<>|;&]+", text):
            if word and os.path.isfile(word) and not word.endswith(OWN_SUFFIXES):
                found.add(os.path.realpath(word))
    return found


def load_spec(d, freezing=False):
    """The eval and the hash that locks it.

    The hash covers eval.json, every other file the eval directory holds at freeze
    (the rule, the known answers, a prompt an arm reads), and any file a command
    names, such as a scorer script kept elsewhere. Changing any of them after freeze
    voids the gates. Files that appear later are outside the lock, and so is any
    file ending .jsonl, .log or .tmp: a file a command writes to must be named so.
    """
    path = os.path.join(d, "eval.json")
    try:
        with open(path, "rb") as f:
            raw = f.read()
        spec = json.loads(raw)
    except (OSError, ValueError) as e:
        raise Refused(f"cannot read {path}: {e}")
    if freezing:
        locked = set()
        for root, dirs, files in os.walk(d):
            if root == d:
                dirs[:] = [x for x in dirs if x not in OWN_DIRS and not x.startswith("runs")]
            locked |= {os.path.join(root, f) for f in files
                       if not (root == d and f in OWN_FILES) and not f.endswith(OWN_SUFFIXES)}
        commands = [(spec.get("scorer") or {}).get("cmd")]
        commands += [arm.get(k) for arm in (spec.get("arms") or {}).values() if isinstance(arm, dict)
                     for k in ("setup", "run")]
        for cmd in commands:
            locked |= files_named(cmd, d)
        locked |= {os.path.realpath(os.path.join(d, t)) for t in spec.get("text_under_test") or []
                   if os.path.isfile(os.path.join(d, t))}
        # The harness and what ships beside it: the judge panel, its prompt, the Jev seat.
        here = os.path.dirname(os.path.abspath(__file__))
        locked |= {os.path.join(here, f) for f in os.listdir(here) if f.endswith((".py", ".json", ".md"))}
    else:
        locked = list(load_state(d).get("locked") or [path])
    digest, each = hashlib.sha256(), {}
    for name in sorted(locked):
        try:
            with open(name, "rb") as f:
                content = f.read()
        except OSError:
            content = b"(missing)"
        each[name] = hashlib.sha256(content).hexdigest()[:12]
        digest.update(os.path.relpath(name, d).encode() + b"\0" + content + b"\0")
    spec["_locked"] = each
    return spec, digest.hexdigest()[:12]


def load_state(d):
    try:
        with open(os.path.join(d, "state.json")) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
    os.replace(tmp, path)


def require(d, gate):
    """Refuse unless every gate before `gate` passed for the eval.json on disk."""
    spec, digest = load_spec(d)
    state = load_state(d)
    if state.get("hash") != digest:
        changed = [name for name, was in (state.get("locked") or {}).items() if spec["_locked"].get(name) != was]
        raise Refused("the eval is not frozen, or a file it uses changed after freeze"
                      + (f" ({', '.join(os.path.relpath(c, d) for c in changed)})" if changed else "")
                      + ": freeze again, which voids every gate. A file a command writes to must end .log or "
                        ".jsonl to stay outside the lock")
    if state.get("verdict") and state.get("ended_on_errors") == gate:
        # Errors are usually passing faults: running the gate again retries the runs that errored.
        del state["verdict"], state["reason"], state["ended_on_errors"]
    if state.get("verdict"):
        raise Refused(f"this eval already ended: {state['verdict']} ({state.get('reason', '')}). Run report.")
    for earlier in GATES[:GATES.index(gate)]:
        if not state.get("gates", {}).get(earlier):
            raise Refused(f"{gate} needs the {earlier} gate to pass first")
    return spec, state


def passed(d, state, gate, **record):
    state.setdefault("gates", {})[gate] = dict(record, at=now())
    save_json(os.path.join(d, "state.json"), state)


def end(d, state, verdict, reason, errors_in=None):
    if errors_in:
        state["ended_on_errors"] = errors_in
        reason += f" Run {errors_in} again to retry them."
    state["verdict"], state["reason"] = verdict, reason
    save_json(os.path.join(d, "state.json"), state)
    print(f"VERDICT: {verdict}. {reason}")


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")


def targets(spec):
    return [c for c in spec["cases"] if c["kind"] == "target"]


def negatives(spec):
    return [c for c in spec["cases"] if c["kind"] == "negative"]


# --- init ---------------------------------------------------------------------

TODO = "TODO: "
SKELETON = {
    "claim": TODO + "one sentence: what the change is claimed to do",
    "counted": TODO + "one sentence: the behaviour an output must show to count, as the scorer will be asked it",
    "human_confirmation": TODO + "the human's own words agreeing that `counted` is what they want measured, "
                                 "or why there is no goal of theirs to check it against",
    "pass_example": TODO + "an output that shows the behaviour",
    "fail_example": TODO + "an output that does not",
    "cannot_show": [TODO + "each thing a verdict from this eval would not tell you"],
    "bar": {"alpha": 0.05, "negatives_max_regressions": 0},
    "arms": {
        "old": {"run": [TODO + "command that prints the old version's output; {input_file} holds the case input"]},
        "new": {"run": [TODO + "the same command with the one thing changed"]},
    },
    "home_instructions_excluded_by": TODO + "how the arm commands keep home-directory instruction files out of a run",
    "cases": [
        {"id": "t1", "kind": "target", "input": TODO + "an input where the old version should fail and the new should not"},
        {"id": "n1", "kind": "negative", "input": TODO + "an input where the behaviour should stay absent"},
    ],
    "scorer": {"cmd": [TODO + "command that prints pass when {output_file} shows the behaviour, fail when it does not; "
                              "for the judge panel: python3 .ai-policy/eval/judges.py --rule-file {eval_dir}/rule.txt "
                              "--output-file {output_file} --case-file {case_file} --log {eval_dir}/judges.jsonl"]},
    "scorer_bar": {"fails_caught": 0.9, "passes_passed": 0.9},
    "known": [{"file": "known/pass-1.txt", "verdict": "pass"}, {"file": "known/fail-1.txt", "verdict": "fail"}],
    "text_under_test": [TODO + "files in the eval directory holding the changed text (or delete this and "
                               "give no_text_under_test_because)"],
    "version_cmds": [],
    "pilot_cases": 4,
    "est_cost_per_run_usd": 0.0,
    "est_seconds_per_run": 60,
}


def gate_init(d, args):
    path = os.path.join(d, "eval.json")
    if os.path.exists(path):
        raise Refused(f"{path} already exists")
    save_json(path, SKELETON)
    os.makedirs(os.path.join(d, "known"), exist_ok=True)
    print(f"wrote {path}: replace every TODO, add cases and at least {MIN_KNOWN} known outputs each way, then freeze")


# --- freeze -------------------------------------------------------------------

def gate_freeze(d, args):
    spec, digest = load_spec(d, freezing=True)
    state = load_state(d)
    # The version counts evals whose results were seen, so freezing again before any result keeps it.
    # A result is anything a gate measured: the scorer on known answers counts, and so does a verdict.
    version = state.get("version", 1)
    archiving = False
    seen_inputs = state.get("seen_inputs", [])  # every case any earlier version of this eval ran
    seen = [x for x in ("scorer", "pilot", "run") if x in state.get("gates", {}) or x in state]
    if seen or os.path.isdir(os.path.join(d, "runs")):
        if not args.new_version:
            raise Refused("this eval already has results. Freezing again after seeing them, changed or not, "
                          "is a new eval: pass --new-version to archive them and say so in the report")
        if os.path.isdir(os.path.join(d, "runs")):
            seen_inputs = sorted(set(seen_inputs) | set(state.get("case_inputs", [])))
        tuned = sorted(set(seen_inputs) & set(case_digests(spec)))
        if arm_changed(state.get("new_arm"), arm_digest(d, spec)) and tuned:
            raise Refused(f"the new arm changed after results on {len(tuned)} of these cases were seen. A change "
                          f"tuned on a case is not scored on it: give the changed arm cases it has not been run on")
        archiving = True
    problems = []

    def need(cond, msg):
        if not cond:
            problems.append(msg)

    need(TODO not in json.dumps({k: v for k, v in spec.items() if k != "_locked"}),
         "a TODO from the skeleton is still in eval.json")
    for key in ("claim", "counted", "human_confirmation", "pass_example", "fail_example"):
        need(isinstance(spec.get(key), str) and spec.get(key, "").strip(), f"`{key}` is missing or empty")
    need(spec.get("cannot_show"), "`cannot_show` must list what this eval cannot show")
    bar = spec.get("bar") or {}
    def number(x, low, high):
        return isinstance(x, (int, float)) and not isinstance(x, bool) and low <= x <= high

    need(number(bar.get("alpha"), 0.0001, MAX_ALPHA), f"`bar.alpha` must be set, at most {MAX_ALPHA}")
    n_neg = sum(1 for c in spec.get("cases") or [] if c.get("kind") == "negative")
    need(number(bar.get("negatives_max_regressions"), 0, max(0, n_neg - 1)) and isinstance(bar.get("negatives_max_regressions"), int),
         "`bar.negatives_max_regressions` must be a whole number below the number of negative cases")
    for arm in ("old", "new"):
        need(((spec.get("arms") or {}).get(arm) or {}).get("run"), f"`arms.{arm}.run` is missing")
    need((spec.get("scorer") or {}).get("cmd"), "`scorer.cmd` is missing")
    sbar = spec.get("scorer_bar") or {}
    need(number(sbar.get("fails_caught"), MIN_SCORER_BAR, 1) and number(sbar.get("passes_passed"), MIN_SCORER_BAR, 1),
         f"`scorer_bar` needs fails_caught and passes_passed, each between {MIN_SCORER_BAR} and 1")
    for pattern in spec.get("private_patterns", []):
        try:
            re.compile(pattern)
        except re.error as e:
            need(False, f"`private_patterns` entry {pattern!r} is not a regular expression: {e}")
    need(number(spec.get("est_cost_per_run_usd"), 0, 10 ** 6), "`est_cost_per_run_usd` must be set, zero or more")
    need(number(spec.get("pilot_cases", 8), 1, 10 ** 6) and isinstance(spec.get("pilot_cases", 8), int),
         "`pilot_cases` must be a whole number")
    need(spec.get("text_under_test") or str(spec.get("no_text_under_test_because", "")).strip(),
         "`text_under_test` must list the files holding the changed text, so cases can be checked against it, "
         "or `no_text_under_test_because` must say why there is none")
    cases = spec.get("cases") or []
    ids = [c.get("id") for c in cases]
    need(len(set(ids)) == len(ids) and all(ids), "every case needs a unique `id`")
    need(all(c.get("kind") in ("target", "negative") and c.get("input") for c in cases),
         "every case needs `kind` (target or negative) and `input`")
    inputs = [c.get("input") for c in cases]
    need(len(set(inputs)) == len(inputs), "two cases have the same input: repeats of one case are not more cases")
    need(not any("rule" in c for c in cases),
         "a case carries its own `rule`: an eval counts one thing, and a negative case passes when the "
         "scorer says that one thing is absent")
    known = spec.get("known") or []
    for verdict in ("pass", "fail"):
        need(sum(1 for k in known if k.get("verdict") == verdict) >= MIN_KNOWN,
             f"`known` needs at least {MIN_KNOWN} outputs whose right answer is {verdict}")
    for k in known:
        need(os.path.isfile(os.path.join(d, k.get("file", ""))), f"known output not found: {k.get('file')}")
    need(len({k.get("file") for k in known}) == len(known), "a known output is listed twice")
    if problems:
        raise Refused("eval.json is not fully stated:\n  - " + "\n  - ".join(problems))

    need_flips = min_flips(bar["alpha"])
    if len(targets(spec)) < need_flips:
        raise Refused(f"{len(targets(spec))} target cases can never reach the {need_flips} flips "
                      f"the sign test needs at {bar['alpha']}: add cases or the eval cannot pass")
    if not negatives(spec):
        raise Refused("no negative case: a change that fires on everything would score perfectly")

    shared = answer_key_overlap(d, spec)
    if archiving:  # only now, once the new eval is known to be sound
        archive = os.path.join(d, f"runs.v{version}")
        if os.path.isdir(os.path.join(d, "runs")):
            shutil.move(os.path.join(d, "runs"), archive)
        os.makedirs(archive, exist_ok=True)
        for stale in ("report.md", "report.json", "splits", "state.json"):  # they describe the archived version
            if os.path.exists(os.path.join(d, stale)):
                shutil.move(os.path.join(d, stale), os.path.join(archive, stale))
        version += 1
    state = {"hash": digest, "version": version, "frozen_at": now(), "gates": {},
             "min_flips": need_flips, "shared_with_text_under_test": shared,
             "new_arm": arm_digest(d, spec), "case_inputs": case_digests(spec), "seen_inputs": seen_inputs,
             "locked": spec["_locked"],
             "versions": versions(spec)}
    passed(d, state, "freeze")
    print(f"frozen {digest} (version {version}): {len(targets(spec))} target and {len(negatives(spec))} "
          f"negative cases, {need_flips} flips needed")
    for case_id, words in shared.items():
        print(f"  case {case_id} shares with the text under test: {', '.join(words)}")


def versions(spec):
    """What ran: this harness, the interpreter, and whatever `version_cmds` report (a model tool's version)."""
    with open(os.path.abspath(__file__), "rb") as f:
        found = {"harness": hashlib.sha256(f.read()).hexdigest()[:12], "python": sys.version.split()[0]}
    for cmd in spec.get("version_cmds") or []:
        try:
            done = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            found[" ".join(cmd)] = (done.stdout or done.stderr).strip()[:200]
        except (subprocess.SubprocessError, OSError) as e:
            found[" ".join(cmd)] = f"not available: {type(e).__name__}"
    return found


def case_digests(spec):
    return [hashlib.sha256(str(c.get("input")).encode()).hexdigest()[:12] for c in spec.get("cases") or []]


def arm_digest(d, spec):
    """The new arm as {name: hash}: its commands, each file they name, and the text under test."""
    arm = (spec.get("arms") or {}).get("new") or {}
    found = {"(commands)": hashlib.sha256(json.dumps(arm, sort_keys=True).encode()).hexdigest()[:12]}
    named = set()
    for k in ("setup", "run"):
        named |= files_named(arm.get(k), d)
    named |= {os.path.join(d, t) for t in spec.get("text_under_test") or []}
    for path in sorted(named):
        try:
            with open(path, "rb") as f:
                found[path] = hashlib.sha256(f.read()).hexdigest()[:12]
        except OSError:
            pass
    return found


def arm_changed(before, after):
    """Whether the new arm differs from the one frozen earlier.

    Only what the earlier arm consisted of is compared, so a log a command has
    written since, which the command also names, is not mistaken for a change.
    """
    return any(after.get(name) != digest for name, digest in (before or {}).items())


def answer_key_overlap(d, spec):
    """Distinctive words and numbers a case shares with the text under test, per case.

    A case that repeats the treated text's own example hands the new arm its answer.
    """
    def tokens(text):
        return set(re.findall(r"[A-Za-z][A-Za-z_-]{6,}|\d{2,}", text.lower()))
    treated = set()
    for path in spec.get("text_under_test", []):
        try:
            with open(os.path.join(d, path), errors="replace") as f:
                treated |= tokens(f.read())
        except OSError as e:
            raise Refused(f"text_under_test not readable: {path}: {e}")
    shared = {c["id"]: sorted(tokens(c["input"]) & treated) for c in spec["cases"]}
    return {case_id: words for case_id, words in shared.items() if words}


# --- context ------------------------------------------------------------------

def gate_context(d, args):
    spec, state = require(d, "context")
    root = work_root(args)
    home = os.path.realpath(os.path.expanduser("~"))
    leaks, parent = [], root
    while True:
        if parent != home:  # the home directory's own files are the globals, checked below
            leaks += [os.path.join(parent, n) for n in INSTRUCTION_FILES if os.path.exists(os.path.join(parent, n))]
        if os.path.dirname(parent) == parent:
            break
        parent = os.path.dirname(parent)
    if leaks:
        end(d, state, UNTESTABLE, "instruction files sit at or above the run directory and would reach both arms: "
            + ", ".join(leaks) + ". Pass --work-root somewhere outside them.")
        return
    globals_found = [p for p in (os.path.join(home, g) for g in GLOBAL_INSTRUCTION_FILES) if os.path.exists(p)]
    if globals_found and not str(spec.get("home_instructions_excluded_by", "")).strip():
        raise Refused("instruction files in the home directory load into a run wherever it starts: "
                      + ", ".join(globals_found) + ". State in `home_instructions_excluded_by` how the arm "
                      "commands shut them out, then freeze again.")
    arms = spec["arms"]
    differ = sorted(k for k in set(arms["old"]) | set(arms["new"]) if arms["old"].get(k) != arms["new"].get(k))
    passed(d, state, "context", work_root=root, arms_differ_in=differ,
           home_instructions=[redact(g, spec)[0] for g in globals_found])
    print(f"nothing leaks from above {root}; the arms differ in: {', '.join(differ) or 'nothing'}")


def work_root(args):
    root = os.path.realpath(args.work_root or tempfile.gettempdir())
    os.makedirs(root, exist_ok=True)
    return root


# --- running arms and scoring ---------------------------------------------------

def fill(cmd, **values):
    """Put values into a command's {placeholders}; any other braces are left as written."""
    out = []
    for part in cmd:
        for name, value in values.items():
            part = part.replace("{" + name + "}", str(value))
        out.append(part)
    return out


_IDENTITY = None


def identity_patterns():
    """Patterns for who the human is: email, and each part of their names, from git and the account."""
    global _IDENTITY
    if _IDENTITY is None:
        try:
            git = {k: subprocess.run(["git", "config", "--global", f"user.{k}"], capture_output=True, text=True).stdout.strip()
                   for k in ("email", "name")}
        except OSError:
            git = {}
        try:
            import pwd
            account = pwd.getpwuid(os.getuid())
            account = f"{account.pw_gecos} {account.pw_name}"
        except (ImportError, KeyError):
            account = ""
        _IDENTITY = [(re.escape(git["email"]), "[email]")] if git.get("email") else []
        names = re.split(r"[^A-Za-z]+", f"{git.get('email', '').split('@')[0]} {git.get('name', '')} {account}")
        _IDENTITY += [(rf"(?i)\b{re.escape(n)}\b", "[name]") for n in sorted(set(names)) if len(n) >= 4]
    return _IDENTITY


def redact(text, spec):
    """Replace the human's private details. Returns the text, how many were replaced,
    and how many of those said who the human is."""
    count = identity = 0
    text, count = re.subn(re.escape(os.path.expanduser("~")), "~", text)
    for pattern, repl in identity_patterns():
        text, n = re.subn(pattern, repl, text)
        identity += n
    for pattern in spec.get("private_patterns", []):
        text, n = re.subn(pattern, "[private]", text)
        count += n
    return text, count + identity, identity


def run_arm(d, spec, phase, case, arm, root):
    """Run one arm on one case in a fresh directory.

    A run that finished is never repeated. One that errored is tried again the next
    time the gate is run, since most errors are a busy provider or a timeout.
    """
    out_dir = os.path.join(d, "runs", phase, case["id"], arm)
    meta_path = os.path.join(out_dir, "meta.json")
    if os.path.isfile(meta_path):
        with open(meta_path) as f:
            saved = json.load(f)
        if not saved["error"]:
            return saved
    os.makedirs(out_dir, exist_ok=True)
    workdir = tempfile.mkdtemp(prefix="aiw-eval-", dir=root)
    input_file = os.path.join(workdir, ".aiw-eval-input.txt")
    with open(input_file, "w") as f:
        f.write(case["input"])
    values = {"workdir": workdir, "input_file": input_file, "case_id": case["id"], "eval_dir": d}
    started = datetime.datetime.now()
    meta = {"case": case["id"], "arm": arm, "phase": phase, "started": now(), "error": None}
    try:
        timeout = spec.get("timeout_s", 900)
        config = spec["arms"][arm]
        if config.get("setup"):
            subprocess.run(fill(config["setup"], **values), cwd=workdir, check=True,
                           capture_output=True, timeout=timeout)
        done = subprocess.run(fill(config["run"], **values), cwd=workdir, capture_output=True,
                              text=True, errors="replace", timeout=timeout)
        if done.returncode != 0:
            meta["error"] = redact(f"exit {done.returncode}: {done.stderr[-300:]}", spec)[0]
        # A model run under the human's account is told who they are, and may greet them by name.
        text, meta["redactions"], meta["identity_seen"] = redact(done.stdout, spec)
        with open(os.path.join(out_dir, "output.txt"), "w") as f:
            f.write(text)
    except (subprocess.SubprocessError, OSError) as e:
        meta["error"] = redact(f"{type(e).__name__}: {str(e)[-300:]}", spec)[0]
    finally:
        shutil.rmtree(workdir, ignore_errors=True)
    if not meta["error"]:
        meta["shows"], meta["split"] = score(d, spec, os.path.join(out_dir, "output.txt"), case)
        if meta["shows"] not in ("pass", "fail"):
            meta["error"] = f"scorer gave no verdict: {meta['shows']}"
        else:
            # One rule for every case. On a negative case the counted behaviour should be
            # absent, so the run passes when the scorer says the output does not show it.
            meta["score"] = as_score(meta["shows"], case)
    meta["seconds"] = round((datetime.datetime.now() - started).total_seconds(), 1)
    save_json(meta_path, meta)
    return meta


def as_score(shows, case):
    """Whether a run passed, from whether its output shows the counted behaviour."""
    if case["kind"] == "negative":
        return {"pass": "fail", "fail": "pass"}[shows]
    return shows


def score(d, spec, output_file, case):
    """Ask the scorer whether an output shows the counted behaviour: pass if it does.

    It sees a copy under a random name, never the arm, and is asked the same
    question of every output, whatever kind of case produced it.

    The scorer prints pass or fail as its last line. A panel of judges that did not
    all agree prints a line reading SPLIT before it. Returns (verdict, split).
    """
    blind = tempfile.mkdtemp(prefix="aiw-eval-score-")
    try:
        copy = os.path.join(blind, uuid.uuid4().hex + ".txt")
        with open(output_file, errors="replace") as f, open(copy, "w") as out:
            out.write(redact(f.read(), spec)[0])  # a known answer is hand-written and may not be clean
        case_file = os.path.join(blind, "case.json")
        with open(case_file, "w") as f:
            json.dump(case, f)
        done = subprocess.run(fill(spec["scorer"]["cmd"], output_file=copy, case_file=case_file, eval_dir=d),
                              capture_output=True, text=True, timeout=spec.get("scorer_timeout_s", 300))
        lines = [line.strip().lower() for line in done.stdout.strip().splitlines()]
        if not lines or lines[-1] not in ("pass", "fail"):
            return redact(f"error: {(done.stderr or done.stdout)[-200:]}", spec)[0], False
        return lines[-1], "split" in lines
    except (subprocess.SubprocessError, OSError) as e:
        return f"error: {type(e).__name__}", False
    finally:
        shutil.rmtree(blind, ignore_errors=True)


def run_many(d, spec, phase, jobs_list, root, jobs):
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        return list(pool.map(lambda j: run_arm(d, spec, phase, j[0], j[1], root), jobs_list))


def approve(args, planned, spec, what, seconds_per_run=None):
    cost = planned * spec["est_cost_per_run_usd"]
    seconds_per_run = seconds_per_run or spec.get("est_seconds_per_run")
    took = f", about {max(1, round(planned * seconds_per_run / max(1, args.jobs) / 60))} min" if seconds_per_run else ""
    print(f"{what}: up to {planned} runs, about ${cost:.2f}{took}")
    if args.approved_runs != planned:
        raise Refused(f"say the spend before making it: pass --approved-runs {planned} once the human has agreed to it")


# --- scorer -------------------------------------------------------------------

def judge_log(d, spec):
    """Where the judge panel logs its votes, read from the scorer command; None for any other scorer."""
    cmd = fill(spec["scorer"]["cmd"], eval_dir=d)
    panel = any(os.path.basename(part) == "judges.py" for part in cmd)
    return cmd[cmd.index("--log") + 1] if panel and "--log" in cmd[:-1] else None


def judge_rates(d, spec, since):
    """Each judge's own record on the known answers, from the rows the panel logged since `since`.

    The panel's majority can hide a judge that passes everything: it is outvoted on
    easy outputs and decides the hard ones. Returns {judge: {"pass": [right, total], "fail": [...]}}.
    """
    right = {}
    for k in spec["known"]:
        with open(os.path.join(d, k["file"]), errors="replace") as f:
            right[hashlib.sha256(redact(f.read(), spec)[0].encode()).hexdigest()[:12]] = k["verdict"]
    rates = {}
    try:
        with open(judge_log(d, spec)) as f:
            f.seek(since)
            rows = [json.loads(line) for line in f if line.strip()]
    except (OSError, ValueError, TypeError):
        return rates
    for row in rows:
        verdict = right.get(row.get("output_sha"))
        for vote in row.get("votes", []) if verdict else []:
            if vote.get("vote"):
                cell = rates.setdefault(vote["judge"], {"pass": [0, 0], "fail": [0, 0]})[verdict]
                cell[0] += vote["vote"] == verdict
                cell[1] += 1
    return rates


def need_review(d, state):
    """Refuse until design-review.md names the frozen eval.

    Asked for before the scorer gate, the first to measure anything, so that fixing
    what the review finds is still the same version.
    """
    review = os.path.join(d, "design-review.md")
    try:
        with open(review) as f:
            reviewed = state["hash"] in f.read()
    except OSError:
        reviewed = False
    if not reviewed:
        raise Refused(f"no design review of this eval: a fresh agent attacks the design before anything is measured, "
                      f"and its findings go in {review} naming the frozen hash {state['hash']}")


def gate_scorer(d, args):
    spec, state = require(d, "scorer")
    need_review(d, state)
    tally = {"pass": [0, 0], "fail": [0, 0]}  # right answer -> [scored right, total]
    misses, splits = [], 0
    log = judge_log(d, spec)
    since = os.path.getsize(log) if log and os.path.exists(log) else 0
    for k in spec["known"]:
        got, split = score(d, spec, os.path.join(d, k["file"]), {"id": None, "kind": "target"})
        splits += split
        tally[k["verdict"]][1] += 1
        if got == k["verdict"]:
            tally[k["verdict"]][0] += 1
        else:
            misses.append(f"{k['file']}: right answer {k['verdict']}, scorer said {got}")
    caught = tally["fail"][0] / tally["fail"][1]
    passed_rate = tally["pass"][0] / tally["pass"][1]
    record = {"fails_caught": f"{tally['fail'][0]}/{tally['fail'][1]}",
              "passes_passed": f"{tally['pass'][0]}/{tally['pass'][1]}", "misses": misses,
              "judges_split_on": splits}
    print(f"scorer on known answers: fails caught {record['fails_caught']}, passes passed {record['passes_passed']}")
    for m in misses:
        print(f"  {m}")
    bar = spec["scorer_bar"]
    if caught < bar["fails_caught"] or passed_rate < bar["passes_passed"]:
        state["scorer"] = record
        end(d, state, UNTESTABLE, f"the scorer missed its bar on known answers (fails caught {record['fails_caught']}, "
            f"passes passed {record['passes_passed']}), so its scores would mean nothing")
        return
    record["judges"] = {}
    rates = judge_rates(d, spec, since)
    if log and not rates:
        state["scorer"] = record
        end(d, state, UNTESTABLE, f"the scorer logs judge votes to {log}, but none were found for the known answers, "
            f"so no judge could be measured alone")
        return
    for judge, r in sorted(rates.items()):
        record["judges"][judge] = f"fails caught {r['fail'][0]}/{r['fail'][1]}, passes passed {r['pass'][0]}/{r['pass'][1]}"
        print(f"  judge {judge}: {record['judges'][judge]}")
        # Alone, a judge is held to the floor, not the panel's bar: the panel exists because single judges err.
        for side in ("fail", "pass"):
            if r[side][1] >= MIN_KNOWN and r[side][0] / r[side][1] < MIN_SCORER_BAR:
                state["scorer"] = record
                end(d, state, UNTESTABLE, f"judge {judge} missed the bar alone ({record['judges'][judge]}). The other "
                    f"judges outvote it on known answers, but on a real output it would split the panel or "
                    f"decide it: replace it in the panel")
                return
    passed(d, state, "scorer", **record)


# --- pilot --------------------------------------------------------------------

def gate_pilot(d, args):
    spec, state = require(d, "pilot")
    need_review(d, state)
    sample = pilot_sample(spec)
    rehearsal = sample[:REHEARSAL_CASES]
    approve(args, len(sample) + len(negatives(spec)) + len(rehearsal), spec,
            "pilot (old arm, plus the new arm on its first cases)")
    root = state["gates"]["context"]["work_root"]
    metas = run_many(d, spec, "pilot", [(c, "old") for c in sample + negatives(spec)], root, args.jobs)
    # The first real outputs, printed to be read before the full spend: a design flaw shows in
    # what a model actually wrote, not in the design. The new arm's are seen here and never counted.
    for m in metas + run_many(d, spec, "pilot", [(c, "new") for c in rehearsal], root, args.jobs):
        try:
            with open(os.path.join(d, "runs", "pilot", m["case"], m["arm"], "output.txt")) as f:
                text = " ".join(f.read().split())[:PILOT_PRINT_CHARS]
        except OSError:
            text = ""
        shows = {"pass": "shows the behaviour", "fail": "does not show it"}.get(m.get("shows"), f"error: {m['error']}")
        print(f"--- {m['case']} ({m['arm']} arm): {shows}{', judges split' if m.get('split') else ''}\n    {text}")
    shown = metas + [m for c in rehearsal for m in [read_meta(d, "pilot", c, "new")] if m]
    named = sum(1 for m in shown if m.get("identity_seen"))
    if named:
        print(f"NOTE: {named} of {len(shown)} outputs named the human. The tool the arms run through tells the model "
              f"who they are; it was replaced before saving and judging, and the report says so.")
    split = sum(1 for m in shown if m.get("split"))
    if split >= 3 and split > len(shown) / 3:
        end(d, state, UNTESTABLE, f"the judges split on {split} of {len(shown)} pilot outputs: what is counted is "
            f"too loose to judge, and a full run would end the same way. Tighten it in a new version")
        return
    if sum(1 for m in metas if m["error"]) > len(metas) * MAX_ERROR_SHARE:
        end(d, state, UNTESTABLE, f"{sum(1 for m in metas if m['error'])} of {len(metas)} pilot runs errored; see runs/pilot.",
            errors_in="pilot")
        return
    # The old arm lacks the change: a negative case where it already shows the behaviour is a bad case.
    broken = [m["case"] for m in metas[len(sample):] if not m["error"] and m["score"] == "fail"]
    if broken:
        end(d, state, UNTESTABLE, f"the old arm already shows the counted behaviour on negative cases {', '.join(broken)}, "
            f"with the change absent: those cases cannot show the change misfiring, so replace them in a new version")
        return
    scored = [m for m in metas[:len(sample)] if not m["error"]]
    if not scored:
        end(d, state, UNTESTABLE, "every pilot run on a target case errored; see runs/pilot.", errors_in="pilot")
        return
    fails = sum(1 for m in scored if m["score"] == "fail")
    projected = fails / len(scored) * len(targets(spec))
    record = {"old_fails": f"{fails}/{len(scored)}", "projected_old_fails": round(projected, 1)}
    print(f"pilot: the old arm failed {record['old_fails']}; about {projected:.0f} of "
          f"{len(targets(spec))} target cases expected to fail, {state['min_flips']} flips needed")
    if projected < state["min_flips"]:
        state["pilot"] = record
        end(d, state, UNTESTABLE, f"the old arm already passes too often (failed {record['old_fails']} in the pilot): "
            f"there is nothing for the new arm to fix on these cases, so no result could show a gain")
        return
    passed(d, state, "pilot", **record)


def pilot_sample(spec):
    """Target cases spread evenly through the list, so its order cannot flatter the pilot."""
    cases = targets(spec)
    n = min(len(cases), max(MIN_PILOT_CASES, spec.get("pilot_cases", 8)))
    return [cases[i * len(cases) // n] for i in range(n)]


# --- run ----------------------------------------------------------------------

def gate_run(d, args):
    spec, state = require(d, "run")
    bar = spec["bar"]
    order = negatives(spec) + targets(spec)
    timed = [m["seconds"] for c in spec["cases"] for m in [read_meta(d, "pilot", c, "old")] if m and not m["error"]]
    approve(args, 2 * len(order), spec, "full run (both arms, stops early once settled)",
            seconds_per_run=sum(timed) / len(timed) if timed else None)
    root = state["gates"]["context"]["work_root"]
    batch = max(1, args.jobs // 2)
    errored = [(c, arm) for c in order for arm in ("old", "new") if (read_meta(d, "main", c, arm) or {}).get("error")]
    run_many(d, spec, "main", errored, root, args.jobs)  # a run that errored last time is tried again first
    done = 0
    while done < len(order):
        chunk = order[done:done + batch]
        run_many(d, spec, "main", [(c, arm) for c in chunk for arm in ("old", "new")], root, args.jobs)
        done += len(chunk)
        if done < len(negatives(spec)):
            continue
        # Stop once no remaining case can change the verdict, however the outputs the judges
        # split on are scored. Running a case is cheaper than asking the human to rule.
        ends = [verdict_of(tally(d, spec, state.get("rulings"), stress), bar, state["min_flips"])[0]
                for stress in ("against new", "for new")]
        if ends[0] and ends[0] == ends[1]:
            break
    passed(d, state, "run", cases_run=done, cases_total=len(order))
    conclude(d, spec, state)


def verdict_of(t, bar, needed):
    """The verdict the counts give so far, or (None, None) while a remaining case could change it."""
    if t["errors"] > MAX_ERROR_SHARE * t["cases"]:
        return UNTESTABLE, f"{t['errors']} of {t['cases']} case pairs errored; see runs/main."
    if t["neg_regressions"] > bar["negatives_max_regressions"]:
        return FAILS, (f"the new arm failed {t['neg_regressions']} negative cases the old arm passed, more than "
                       f"the {bar['negatives_max_regressions']} the bar allows: it fires where it should not")
    if t["old_wins"] > t["new_wins"] and sign_test(t["new_wins"], t["old_wins"] ) < bar["alpha"] \
            and settled(t["new_wins"], t["old_wins"], t["targets_left"], bar["alpha"]) == FAILS:
        return FAILS, (f"the change made things worse: {t['old_wins']} cases flipped toward old and "
                       f"{t['new_wins']} toward new, sign test p = {sign_test(t['new_wins'], t['old_wins']):.3f}")
    old_failed = t["new_wins"] + t["both_fail"]
    if old_failed + t["targets_left"] < needed and t["old_wins"] <= t["new_wins"]:
        # The pilot's sample suggested otherwise, and it was wrong: saying "does not work" here
        # would blame the change for a test that could not have shown it working.
        return UNTESTABLE, (f"the old arm failed only {old_failed} target cases and {needed} flips are needed, "
                            f"so no result on these cases could show a gain: add cases the old arm fails")
    verdict = settled(t["new_wins"], t["old_wins"], t["targets_left"], bar["alpha"])
    if not verdict:
        return None, None
    broke = (f". The change broke {t['old_wins']} cases the old arm passed"
             if verdict == FAILS and t["old_wins"] > t["new_wins"] else "")
    return verdict, (f"flips toward new {t['new_wins']}, toward old {t['old_wins']}, "
                     f"sign test p = {sign_test(t['new_wins'], t['old_wins']):.3f} against {bar['alpha']}{broke}")


def conclude(d, spec, state):
    """End the eval, unless outputs the judges split on could change the verdict.

    Each such output is scored both ways. If the verdict is the same either way, the
    splits do not matter and nobody is asked. Otherwise the human rules on them,
    blind to the arm, up to MAX_RULINGS; more than that means the rule is too loose
    to judge.
    """
    bar, needed = spec["bar"], state["min_flips"]
    rulings = state.setdefault("rulings", {})
    low = verdict_of(tally(d, spec, rulings, "against new"), bar, needed)
    high = verdict_of(tally(d, spec, rulings, "for new"), bar, needed)
    if low[0] == high[0]:
        state.pop("awaiting", None)
        t = tally(d, spec, rulings)
        verdict, reason = verdict_of(t, bar, needed)
        end(d, state, verdict, reason, errors_in="run" if t["errors"] > MAX_ERROR_SHARE * t["cases"] else None)
        return
    open_splits = sorted((hashlib.sha256(f"{state['hash']}{c['id']}{arm}".encode()).hexdigest()[:6], c["id"], arm)
                         for c in spec["cases"] for arm in ("old", "new")
                         if (read_meta(d, "main", c, arm) or {}).get("split") and f"{c['id']}/{arm}" not in rulings)
    if len(open_splits) > MAX_RULINGS:
        end(d, state, UNTESTABLE, f"the judges split on {len(open_splits)} outputs and the verdict turns on them: "
            f"the rule is too loose to judge, so tighten what is counted and run a new version")
        return
    state["awaiting"] = {sid: f"{case_id}/{arm}" for sid, case_id, arm in open_splits}
    for sid, case_id, arm in open_splits:
        os.makedirs(os.path.join(d, "splits"), exist_ok=True)
        shutil.copyfile(os.path.join(d, "runs", "main", case_id, arm, "output.txt"),
                        os.path.join(d, "splits", f"{sid}.txt"))
    save_json(os.path.join(d, "state.json"), state)
    print(f"RULING NEEDED: the judges split on {len(open_splits)} outputs and the verdict turns on them. "
          f"The human reads each file in {os.path.join(d, 'splits')}, without being told which arm or case "
          f"it came from, and answers one question of each: does it show this? {spec['counted']}\n"
          f"  pass = it shows it, fail = it does not: harness.py rule --dir {d} --id <name> --verdict pass|fail")


def gate_rule(d, args):
    spec, digest = load_spec(d)
    state = load_state(d)
    if state.get("hash") != digest or args.id not in state.get("awaiting", {}):
        raise Refused(f"no ruling is awaited on {args.id!r} for this eval")
    if args.verdict not in ("pass", "fail"):
        raise Refused("--verdict must be pass or fail")
    state["rulings"][state["awaiting"].pop(args.id)] = args.verdict
    save_json(os.path.join(d, "state.json"), state)
    if state["awaiting"]:
        print(f"ruled; {len(state['awaiting'])} still awaited: {', '.join(sorted(state['awaiting']))}")
    else:
        conclude(d, spec, state)


def read_meta(d, phase, case, arm):
    try:
        with open(os.path.join(d, "runs", phase, case["id"], arm, "meta.json")) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def tally(d, spec, rulings=None, stress=None):
    """Count the saved main-phase pairs. Only cases one arm passed and the other failed are flips.

    A human ruling replaces the judges' score. With `stress`, every output the judges
    split on and nobody ruled on is scored as badly ("against new") or as well
    ("for new") for the new arm as it could be.
    """
    rulings = rulings or {}

    def scored(meta, case, arm):
        key = f"{case['id']}/{arm}"
        if key in rulings:
            # The human answers what the judges were asked: does the output show the behaviour?
            return as_score(rulings[key], case)
        if stress and meta.get("split"):
            return "pass" if (arm == "new") == (stress == "for new") else "fail"
        return meta["score"]

    t = {"new_wins": 0, "old_wins": 0, "both_pass": 0, "both_fail": 0, "errors": 0, "pairs": 0,
         "neg_regressions": 0, "neg_new_fails": 0, "neg_old_fails": 0, "flips": [], "targets_left": 0,
         "same_arm_cases": 0, "same_arm_flips": 0, "splits": 0, "cases": len(spec["cases"])}
    for c in spec["cases"]:
        old, new = read_meta(d, "main", c, "old"), read_meta(d, "main", c, "new")
        if not old or not new:
            t["targets_left"] += c["kind"] == "target"
            continue
        if old["error"] or new["error"]:
            t["errors"] += 1
            continue
        t["pairs"] += 1
        t["splits"] += bool(old.get("split")) + bool(new.get("split"))
        pair = (scored(old, c, "old"), scored(new, c, "new"))
        if c["kind"] == "negative":
            # A negative case both arms fail is noise or a bad case, not the change firing.
            t["neg_regressions"] += pair == ("pass", "fail")
            t["neg_new_fails"] += pair[1] == "fail"
            t["neg_old_fails"] += pair[0] == "fail"
            continue
        key = {("fail", "pass"): "new_wins", ("pass", "fail"): "old_wins",
               ("pass", "pass"): "both_pass", ("fail", "fail"): "both_fail"}[pair]
        t[key] += 1
        if key in ("new_wins", "old_wins"):
            t["flips"].append({"case": c["id"], "toward": key[:3]})
        # The pilot ran the old arm on this case too: two runs of one arm show the noise.
        pilot = read_meta(d, "pilot", c, "old")
        if pilot and not pilot["error"]:
            t["same_arm_cases"] += 1
            t["same_arm_flips"] += pilot["score"] != old["score"]
    return t


# --- report -------------------------------------------------------------------

def gate_report(d, args):
    spec, digest = load_spec(d)
    state = load_state(d)
    if state.get("hash") != digest:
        raise Refused("eval.json changed after freeze; this report would describe a different eval")
    if not state.get("verdict"):
        raise Refused("no verdict yet: the gates have not finished"
                      + (f", and rulings are awaited on {', '.join(sorted(state['awaiting']))}" if state.get("awaiting") else ""))
    t = tally(d, spec, state.get("rulings"))
    redactions = named = 0
    for root, _, files in os.walk(os.path.join(d, "runs")):
        if "meta.json" in files:
            with open(os.path.join(root, "meta.json")) as f:
                meta = json.load(f)
            redactions += meta.get("redactions", 0)
            named += bool(meta.get("identity_seen"))
    split_outputs = []
    for c in spec["cases"]:
        for arm in ("old", "new"):
            meta = read_meta(d, "main", c, arm)
            if meta and meta.get("split"):
                ruled = state.get("rulings", {}).get(f"{c['id']}/{arm}")
                judged = "shows the behaviour" if meta["shows"] == "pass" else "does not show it"
                split_outputs.append(f"{c['id']} ({arm} arm): the judges' majority said it {judged}"
                                     + (f"; the human ruled {ruled}" if ruled else ""))
    report = {"verdict": state["verdict"], "reason": state.get("reason"), "eval_hash": digest,
              "eval_version": state.get("version"), "claim": spec["claim"], "counted": spec["counted"],
              "bar": spec["bar"], "gates": state.get("gates"), "tally": t,
              "sign_test_p": sign_test(t["new_wins"], t["old_wins"]), "cannot_show": spec["cannot_show"],
              "redactions": redactions, "outputs_naming_the_human": named, "arms": spec["arms"],
              "rulings": state.get("rulings", {}), "split_outputs": split_outputs,
              "versions": state.get("versions"), "shared_with_text_under_test": state.get("shared_with_text_under_test"),
              "human_confirmation": spec["human_confirmation"], "written": now()}
    save_json(os.path.join(d, "report.json"), json.loads(redact(json.dumps(report), spec)[0]))
    lines = [f"# Eval report: {state['verdict']}", "", state.get("reason", ""), "",
             f"- Claim: {spec['claim']}", f"- Counted: {spec['counted']}",
             f"- Bar, set before the run: sign test under {spec['bar']['alpha']} on the flips; at most "
             f"{spec['bar']['negatives_max_regressions']} negative cases the new arm fails and the old arm passes",
             f"- Eval {digest}, version {state.get('version')}"
             + (" (changed after earlier results were seen)" if state.get("version", 1) > 1 else ""), ""]
    if state.get("gates", {}).get("run"):
        run = state["gates"]["run"]
        lines += ["## Counts", "",
                  f"- Cases run: {run['cases_run']} of {run['cases_total']} (stops once no remaining case can change the verdict)",
                  f"- Target cases: {t['new_wins']} flipped toward new, {t['old_wins']} toward old, "
                  f"{t['both_pass']} both passed, {t['both_fail']} both failed",
                  f"- Negative cases failed: new {t['neg_new_fails']}, old {t['neg_old_fails']}; "
                  f"failed by new and passed by old: {t['neg_regressions']}",
                  f"- Same arm twice (pilot and run, old arm): {t['same_arm_flips']} of {t['same_arm_cases']} cases changed score",
                  f"- Outputs the judges split on: {t['splits']}; ruled on by the human: {len(state.get('rulings', {}))}",
                  f"- Pairs dropped for errors: {t['errors']}", ""]
        lines += ["## Flips", ""] + [f"- {f['case']}: toward {f['toward']}" for f in t["flips"]] + [""]
        if split_outputs:
            lines += ["## Outputs the judges split on", ""] + [f"- {x}" for x in split_outputs] + [""]
    lines += ["## Gates", ""]
    for gate in GATES:
        record = (state.get("gates") or {}).get(gate)
        lines.append(f"- {gate}: " + (json.dumps({k: v for k, v in record.items() if k != 'at'}) if record else "not passed"))
    lines += ["", "## What this eval cannot show", ""] + [f"- {x}" for x in spec["cannot_show"]]
    lines += ["", "## Taken on the worker's word", "",
              "The harness cannot check who wrote these. They are shown so the human can.", "",
              f"- The human's agreement to what is counted, as recorded: {spec['human_confirmation']}",
              f"- A fresh agent's review of this design: design-review.md names this eval's hash."]
    shared = state.get("shared_with_text_under_test") or {}
    lines += ["", "## Cases against the text under test", ""]
    if spec.get("text_under_test"):
        lines += [f"- {case_id} shares: {', '.join(words)}" for case_id, words in shared.items()] or \
                 ["- No case shares a distinctive word or number with it."]
    else:
        lines += [f"- Not checked: {spec.get('no_text_under_test_because')}"]
    lines += ["", "## Private details", "",
              f"- Replaced in saved outputs: {redactions}.",
              f"- Outputs that named the human: {named}." + (
                  " The tool the arms run through told the model who they are; the name was replaced "
                  "before the output was saved or judged, but it did enter the run." if named else "")]
    lines += ["", "## What ran", ""] + [f"- {k}: {v}" for k, v in (state.get("versions") or {}).items()]
    with open(os.path.join(d, "report.md"), "w") as f:
        f.write(redact("\n".join(lines) + "\n", spec)[0])
    print(f"VERDICT: {state['verdict']}. Report: {os.path.join(d, 'report.md')}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("gate", choices=["init"] + GATES + ["rule", "report"])
    parser.add_argument("--dir", required=True, help="the eval directory holding eval.json")
    parser.add_argument("--work-root", help="where run directories are made (default: the system temp directory)")
    parser.add_argument("--approved-runs", type=int, help="the run count the human agreed to")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--id", help="rule: the name of the split output")
    parser.add_argument("--verdict", help="rule: pass or fail")
    parser.add_argument("--new-version", action="store_true", help="freeze a changed eval after results exist")
    args = parser.parse_args(argv)
    d = os.path.realpath(args.dir)
    try:
        globals()[f"gate_{args.gate}"](d, args)
    except Refused as e:
        print(f"REFUSED: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
