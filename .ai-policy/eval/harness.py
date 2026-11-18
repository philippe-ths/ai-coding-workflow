"""Run a behavioural eval of one change, old against new, through gates that cannot be skipped.

Usage:
  python3 .ai-policy/eval/harness.py <gate> --dir <eval directory> [options]

The eval directory holds `eval.json`, written before any run, and everything the
harness saves. Gates run in this order, cheapest first, and each refuses until
the one before it has passed for the same `eval.json`:

  freeze    check the eval is fully stated (claim, bar, cases, scorer) and lock it
  context   check no instruction file leaks into a run from the directories above it
  scorer    measure the scorer on known answers, both ways
  pilot     run the old arm on a few cases: is there anything for the new arm to fix?
  run       run both arms on every case, stopping once the result is settled
  rule      record the human's pass or fail on an output the judges split on
  report    write report.md and report.json

Every eval ends in one of three verdicts: "works", "does not work", or "cannot be
tested this way". The last comes from context, scorer or pilot, before the full
spend. Changing `eval.json` after freeze voids every gate.

`pilot` and `run` print how many runs they will make and what that costs, and need
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
MAX_ERROR_SHARE = 0.1
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

def load_spec(d):
    path = os.path.join(d, "eval.json")
    try:
        with open(path, "rb") as f:
            raw = f.read()
        return json.loads(raw), hashlib.sha256(raw).hexdigest()[:12]
    except (OSError, ValueError) as e:
        raise Refused(f"cannot read {path}: {e}")


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
        raise Refused("eval.json is not frozen, or changed after freeze: run freeze again (this voids every gate)")
    if state.get("verdict"):
        raise Refused(f"this eval already ended: {state['verdict']} ({state.get('reason', '')}). Run report.")
    for earlier in GATES[:GATES.index(gate)]:
        if not state.get("gates", {}).get(earlier):
            raise Refused(f"{gate} needs the {earlier} gate to pass first")
    return spec, state


def passed(d, state, gate, **record):
    state.setdefault("gates", {})[gate] = dict(record, at=now())
    save_json(os.path.join(d, "state.json"), state)


def end(d, state, verdict, reason):
    state["verdict"], state["reason"] = verdict, reason
    save_json(os.path.join(d, "state.json"), state)
    print(f"VERDICT: {verdict}. {reason}")


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")


def targets(spec):
    return [c for c in spec["cases"] if c["kind"] == "target"]


def negatives(spec):
    return [c for c in spec["cases"] if c["kind"] == "negative"]


# --- freeze -------------------------------------------------------------------

def gate_freeze(d, args):
    spec, digest = load_spec(d)
    state = load_state(d)
    # The version counts evals whose results were seen, so freezing again before any run keeps it.
    version = state.get("version", 1)
    if os.path.isdir(os.path.join(d, "runs")) and state.get("hash") != digest:
        if not args.new_version:
            raise Refused("runs exist for an earlier eval.json. Changing the eval after seeing results "
                          "is a new eval: pass --new-version to archive them and say so in the report")
        shutil.move(os.path.join(d, "runs"), os.path.join(d, f"runs.v{version}"))
        version += 1
    problems = []

    def need(cond, msg):
        if not cond:
            problems.append(msg)

    for key in ("claim", "counted", "human_confirmation", "pass_example", "fail_example"):
        need(isinstance(spec.get(key), str) and spec.get(key, "").strip(), f"`{key}` is missing or empty")
    need(spec.get("cannot_show"), "`cannot_show` must list what this eval cannot show")
    bar = spec.get("bar") or {}
    need(isinstance(bar.get("alpha"), (int, float)) and 0 < bar.get("alpha", 0) < 1, "`bar.alpha` must be set")
    need(isinstance(bar.get("negatives_max_regressions"), int), "`bar.negatives_max_regressions` must be set")
    for arm in ("old", "new"):
        need(((spec.get("arms") or {}).get(arm) or {}).get("run"), f"`arms.{arm}.run` is missing")
    need((spec.get("scorer") or {}).get("cmd"), "`scorer.cmd` is missing")
    sbar = spec.get("scorer_bar") or {}
    need("fails_caught" in sbar and "passes_passed" in sbar, "`scorer_bar` needs fails_caught and passes_passed")
    need(isinstance(spec.get("est_cost_per_run_usd"), (int, float)), "`est_cost_per_run_usd` must be set")
    cases = spec.get("cases") or []
    ids = [c.get("id") for c in cases]
    need(len(set(ids)) == len(ids) and all(ids), "every case needs a unique `id`")
    need(all(c.get("kind") in ("target", "negative") and c.get("input") for c in cases),
         "every case needs `kind` (target or negative) and `input`")
    known = spec.get("known") or []
    for verdict in ("pass", "fail"):
        need(sum(1 for k in known if k.get("verdict") == verdict) >= MIN_KNOWN,
             f"`known` needs at least {MIN_KNOWN} outputs whose right answer is {verdict}")
    for k in known:
        need(os.path.isfile(os.path.join(d, k.get("file", ""))), f"known output not found: {k.get('file')}")
    if problems:
        raise Refused("eval.json is not fully stated:\n  - " + "\n  - ".join(problems))

    need_flips = min_flips(bar["alpha"])
    if len(targets(spec)) < need_flips:
        raise Refused(f"{len(targets(spec))} target cases can never reach the {need_flips} flips "
                      f"the sign test needs at {bar['alpha']}: add cases or the eval cannot pass")
    if not negatives(spec):
        raise Refused("no negative case: a change that fires on everything would score perfectly")

    shared = answer_key_overlap(d, spec)
    state = {"hash": digest, "version": version, "frozen_at": now(), "gates": {},
             "min_flips": need_flips, "shared_with_text_under_test": shared}
    passed(d, state, "freeze")
    print(f"frozen {digest} (version {version}): {len(targets(spec))} target and {len(negatives(spec))} "
          f"negative cases, {need_flips} flips needed")
    for case_id, words in shared.items():
        print(f"  case {case_id} shares with the text under test: {', '.join(words)}")


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
    if not treated:
        return {}
    common = None
    per_case = {}
    for c in spec["cases"]:
        per_case[c["id"]] = tokens(c["input"]) & treated
        common = per_case[c["id"]] if common is None else common & per_case[c["id"]]
    return {cid: sorted(t - common) for cid, t in per_case.items() if t - common}


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
    passed(d, state, "context", work_root=root, arms_differ_in=differ, home_instructions=globals_found)
    print(f"nothing leaks from above {root}; the arms differ in: {', '.join(differ) or 'nothing'}")


def work_root(args):
    root = os.path.realpath(args.work_root or tempfile.gettempdir())
    os.makedirs(root, exist_ok=True)
    return root


# --- running arms and scoring ---------------------------------------------------

def fill(cmd, **values):
    return [part.format(**values) for part in cmd]


def redact(text, spec):
    """Replace the human's private details before anything is saved."""
    count = 0
    patterns = [(re.escape(os.path.expanduser("~")), "~")]
    # A model run under the human's account is told who they are, and may greet them by name.
    try:
        git = {k: subprocess.run(["git", "config", "--global", f"user.{k}"], capture_output=True, text=True).stdout.strip()
               for k in ("email", "name")}
    except OSError:
        git = {}
    if git.get("email"):
        patterns.append((re.escape(git["email"]), "[email]"))
    names = re.split(r"[^A-Za-z]+", git.get("email", "").split("@")[0] + " " + git.get("name", ""))
    patterns += [(rf"(?i)\b{re.escape(n)}\b", "[name]") for n in sorted(set(names)) if len(n) >= 4]
    patterns += [(p, "[private]") for p in spec.get("private_patterns", [])]
    for pattern, repl in patterns:
        text, n = re.subn(pattern, repl, text)
        count += n
    return text, count


def run_arm(d, spec, phase, case, arm, root):
    """Run one arm on one case in a fresh directory; a finished run is never repeated."""
    out_dir = os.path.join(d, "runs", phase, case["id"], arm)
    meta_path = os.path.join(out_dir, "meta.json")
    if os.path.isfile(meta_path):
        with open(meta_path) as f:
            return json.load(f)
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
            meta["error"] = f"exit {done.returncode}: {done.stderr[-300:]}"
        text, meta["redactions"] = redact(done.stdout, spec)
        with open(os.path.join(out_dir, "output.txt"), "w") as f:
            f.write(text)
    except (subprocess.SubprocessError, OSError) as e:
        meta["error"] = f"{type(e).__name__}: {str(e)[-300:]}"
    finally:
        shutil.rmtree(workdir, ignore_errors=True)
    meta["seconds"] = round((datetime.datetime.now() - started).total_seconds(), 1)
    if not meta["error"]:
        meta["score"], meta["split"] = score(d, spec, os.path.join(out_dir, "output.txt"), case)
        if meta["score"] not in ("pass", "fail"):
            meta["error"] = f"scorer gave no verdict: {meta['score']}"
    save_json(meta_path, meta)
    return meta


def score(d, spec, output_file, case):
    """Ask the scorer for pass or fail. It sees a copy under a random name, never the arm.

    The scorer prints pass or fail as its last line. A panel of judges that did not
    all agree prints a line reading SPLIT before it. Returns (verdict, split).
    """
    blind = tempfile.mkdtemp(prefix="aiw-eval-score-")
    try:
        copy = os.path.join(blind, uuid.uuid4().hex + ".txt")
        shutil.copyfile(output_file, copy)
        case_file = os.path.join(blind, "case.json")
        with open(case_file, "w") as f:
            json.dump(case, f)
        done = subprocess.run(fill(spec["scorer"]["cmd"], output_file=copy, case_file=case_file, eval_dir=d),
                              capture_output=True, text=True, timeout=spec.get("scorer_timeout_s", 300))
        lines = [line.strip().lower() for line in done.stdout.strip().splitlines()]
        if not lines or lines[-1] not in ("pass", "fail"):
            return f"error: {(done.stderr or done.stdout)[-200:]}", False
        return lines[-1], "split" in lines
    except (subprocess.SubprocessError, OSError) as e:
        return f"error: {type(e).__name__}", False
    finally:
        shutil.rmtree(blind, ignore_errors=True)


def run_many(d, spec, phase, jobs_list, root, jobs):
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        return list(pool.map(lambda j: run_arm(d, spec, phase, j[0], j[1], root), jobs_list))


def approve(args, planned, spec, what):
    cost = planned * spec["est_cost_per_run_usd"]
    print(f"{what}: up to {planned} runs, about ${cost:.2f}")
    if args.approved_runs != planned:
        raise Refused(f"say the spend before making it: pass --approved-runs {planned} once the human has agreed to it")


# --- scorer -------------------------------------------------------------------

def gate_scorer(d, args):
    spec, state = require(d, "scorer")
    by_id = {c["id"]: c for c in spec["cases"]}
    tally = {"pass": [0, 0], "fail": [0, 0]}  # right answer -> [scored right, total]
    misses, splits = [], 0
    for k in spec["known"]:
        got, split = score(d, spec, os.path.join(d, k["file"]),
                           by_id.get(k.get("case"), {"id": k.get("case"), "kind": "target"}))
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
    passed(d, state, "scorer", **record)


# --- pilot --------------------------------------------------------------------

def gate_pilot(d, args):
    spec, state = require(d, "pilot")
    review = os.path.join(d, "design-review.md")
    try:
        with open(review) as f:
            reviewed = state["hash"] in f.read()
    except OSError:
        reviewed = False
    if not reviewed:
        raise Refused(f"no design review of this eval: a fresh agent attacks the design before any spend, and its "
                      f"findings go in {review} naming the frozen hash {state['hash']}")
    sample = targets(spec)[:spec.get("pilot_cases", 8)]
    approve(args, len(sample) + len(negatives(spec)), spec, "pilot (old arm only)")
    root = state["gates"]["context"]["work_root"]
    metas = run_many(d, spec, "pilot", [(c, "old") for c in sample + negatives(spec)], root, args.jobs)
    if sum(1 for m in metas if m["error"]) > len(metas) * MAX_ERROR_SHARE:
        end(d, state, UNTESTABLE, f"{sum(1 for m in metas if m['error'])} of {len(metas)} pilot runs errored; see runs/pilot")
        return
    # The old arm lacks the change, so it cannot fire: a negative case it fails is a bad case or rule.
    broken = [m["case"] for m in metas[len(sample):] if not m["error"] and m["score"] == "fail"]
    if broken:
        end(d, state, UNTESTABLE, f"the old arm fails negative cases {', '.join(broken)}, where the change is absent: "
            f"those cases or their rule mark something other than the change firing, so fix them in a new version")
        return
    scored = [m for m in metas[:len(sample)] if not m["error"]]
    if not scored:
        end(d, state, UNTESTABLE, "every pilot run on a target case errored; see runs/pilot")
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


# --- run ----------------------------------------------------------------------

def gate_run(d, args):
    spec, state = require(d, "run")
    bar = spec["bar"]
    order = negatives(spec) + targets(spec)
    approve(args, 2 * len(order), spec, "full run (both arms, stops early once settled)")
    root = state["gates"]["context"]["work_root"]
    batch = max(1, args.jobs // 2)
    done = 0
    while done < len(order):
        chunk = order[done:done + batch]
        run_many(d, spec, "main", [(c, arm) for c in chunk for arm in ("old", "new")], root, args.jobs)
        done += len(chunk)
        t = tally(d, spec)
        if t["neg_regressions"] > bar["negatives_max_regressions"]:
            break
        if done >= len(negatives(spec)) and settled(t["new_wins"], t["old_wins"], t["targets_left"], bar["alpha"]):
            break
    passed(d, state, "run", cases_run=done, cases_total=len(order))
    conclude(d, spec, state)


def verdict_of(t, bar):
    if t["errors"] > MAX_ERROR_SHARE * max(1, t["pairs"] + t["errors"]):
        return UNTESTABLE, f"{t['errors']} of {t['pairs'] + t['errors']} case pairs errored; see runs/main"
    if t["neg_regressions"] > bar["negatives_max_regressions"]:
        return FAILS, (f"the new arm failed {t['neg_regressions']} negative cases the old arm passed, more than "
                       f"the {bar['negatives_max_regressions']} the bar allows: it fires where it should not")
    verdict = settled(t["new_wins"], t["old_wins"], t["targets_left"], bar["alpha"]) or FAILS
    return verdict, (f"flips toward new {t['new_wins']}, toward old {t['old_wins']}, "
                     f"sign test p = {sign_test(t['new_wins'], t['old_wins']):.3f} against {bar['alpha']}")


def conclude(d, spec, state):
    """End the eval, unless outputs the judges split on could change the verdict.

    Each such output is scored both ways. If the verdict is the same either way, the
    splits do not matter and nobody is asked. Otherwise the human rules on them,
    blind to the arm, up to MAX_RULINGS; more than that means the rule is too loose
    to judge.
    """
    bar = spec["bar"]
    rulings = state.setdefault("rulings", {})
    low = verdict_of(tally(d, spec, rulings, "against new"), bar)
    high = verdict_of(tally(d, spec, rulings, "for new"), bar)
    if low[0] == high[0]:
        end(d, state, *verdict_of(tally(d, spec, rulings), bar))
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
          f"The human reads each file in {os.path.join(d, 'splits')} and rules: "
          f"harness.py rule --dir {d} --id <name> --verdict pass|fail")


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
            return rulings[key]
        if stress and meta.get("split"):
            return "pass" if (arm == "new") == (stress == "for new") else "fail"
        return meta["score"]

    t = {"new_wins": 0, "old_wins": 0, "both_pass": 0, "both_fail": 0, "errors": 0, "pairs": 0,
         "neg_regressions": 0, "neg_new_fails": 0, "neg_old_fails": 0, "flips": [], "targets_left": 0,
         "same_arm_cases": 0, "same_arm_flips": 0, "splits": 0}
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
    redactions = 0
    for root, _, files in os.walk(os.path.join(d, "runs")):
        if "meta.json" in files:
            with open(os.path.join(root, "meta.json")) as f:
                redactions += json.load(f).get("redactions", 0)
    report = {"verdict": state["verdict"], "reason": state.get("reason"), "eval_hash": digest,
              "eval_version": state.get("version"), "claim": spec["claim"], "counted": spec["counted"],
              "bar": spec["bar"], "gates": state.get("gates"), "tally": t,
              "sign_test_p": sign_test(t["new_wins"], t["old_wins"]), "cannot_show": spec["cannot_show"],
              "redactions": redactions, "arms": spec["arms"], "rulings": state.get("rulings", {}), "written": now()}
    save_json(os.path.join(d, "report.json"), report)
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
    lines += ["## Gates", ""]
    for gate in GATES:
        record = (state.get("gates") or {}).get(gate)
        lines.append(f"- {gate}: " + (json.dumps({k: v for k, v in record.items() if k != 'at'}) if record else "not passed"))
    lines += ["", "## What this eval cannot show", ""] + [f"- {x}" for x in spec["cannot_show"]]
    lines += ["", f"Private details replaced in saved outputs: {redactions}."]
    with open(os.path.join(d, "report.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"VERDICT: {state['verdict']}. Report: {os.path.join(d, 'report.md')}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("gate", choices=GATES + ["rule", "report"])
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
