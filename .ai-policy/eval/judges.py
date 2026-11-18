"""Score one output against one rule with a panel of judges from different providers.

Usage, as the `scorer.cmd` of an eval:
  python3 .ai-policy/eval/judges.py --rule-file RULE --output-file {output_file}
      --case-file {case_file} --log {eval_dir}/judges.jsonl [--panel PANEL.json]

Each judge in the panel is a command that reads the prompt on stdin and answers on
stdout. It gets judge-prompt.md, the rule and the output, and nothing else: not
the case, not which arm wrote the output, not what the other judges said. Where a
judge's own tool loads a file from the home directory that no option shuts out,
the panel names it as `still_loads` and each log row records it. A case
that carries its own `rule` (a negative case usually does) is judged against that
instead of the rule file.

Prints the majority verdict, pass or fail, as the last line, with a line reading
SPLIT before it when the judges did not all agree. A tie counts as fail. Appends
one row per call to the log: every judge's vote, reasoning and time.

Exit codes: 0 a verdict was printed, 1 fewer than two judges answered (no verdict),
2 usage error.
"""

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
# Seconds to wait before each try. A busy provider turns a judge away; a missing judge
# leaves two, whose disagreement is a tie, so a judge is tried again before it is dropped.
RETRY_WAITS = [float(w) for w in os.environ.get("AIW_EVAL_JUDGE_RETRY_WAITS", "0 10 30").split()]


def ask(judge, message, timeout):
    """One judge's vote: pass, fail, or None when it gave no usable answer after retries."""
    started = time.time()
    cmd = [part.replace("{here}", HERE) for part in judge["cmd"]]
    answer, vote, problem = "", None, None
    for wait in RETRY_WAITS:
        time.sleep(wait)
        try:
            # An empty directory, so the judge's own tool finds no project files to load.
            with tempfile.TemporaryDirectory(prefix="aiw-eval-judge-") as cwd:
                done = subprocess.run(cmd, input=message, capture_output=True, text=True,
                                      errors="replace", cwd=cwd, timeout=timeout)
            answer = done.stdout.strip()
            lines = [re.sub(r"[^A-Za-z]", "", line).upper() for line in answer.splitlines() if line.strip()]
            vote = lines[-1].lower() if lines and lines[-1] in ("PASS", "FAIL") else None
            problem = None if vote else f"no PASS or FAIL line (exit {done.returncode}): {done.stderr[-200:]}"
        except (subprocess.SubprocessError, OSError) as e:
            problem = f"{type(e).__name__}: {str(e)[-200:]}"
        if vote:
            break
    # A file the judge's own tool loads whatever we pass it: recorded, since it is not sealed out.
    loads = judge.get("still_loads")
    loaded = loads if loads and os.path.exists(os.path.expanduser(loads)) else None
    return {"judge": judge["name"], "provider": judge.get("provider"), "vote": vote, "answer": answer,
            "still_loaded": loaded, "problem": problem, "seconds": round(time.time() - started, 1)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--rule-file", required=True)
    parser.add_argument("--output-file", required=True)
    parser.add_argument("--case-file")
    parser.add_argument("--log", required=True)
    parser.add_argument("--panel", default=os.path.join(HERE, "panel.json"))
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args(argv)
    try:
        with open(args.panel) as f:
            panel = json.load(f)
        with open(os.path.join(HERE, "judge-prompt.md")) as f:
            prompt = f.read()
        with open(args.output_file, errors="replace") as f:
            output = f.read()
        case = {}
        if args.case_file:
            with open(args.case_file) as f:
                case = json.load(f)
        rule = case.get("rule")
        if not rule:
            with open(args.rule_file) as f:
                rule = f.read()
    except (OSError, ValueError) as e:
        print(f"judges: {e}", file=sys.stderr)
        return 2

    message = f"{prompt}\n<rule>\n{rule.strip()}\n</rule>\n\n<output>\n{output.strip()}\n</output>\n"
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(panel)) as pool:
        votes = list(pool.map(lambda judge: ask(judge, message, args.timeout), panel))
    counted = [v["vote"] for v in votes if v["vote"]]
    passes, fails = counted.count("pass"), counted.count("fail")
    verdict = None if len(counted) < 2 else ("pass" if passes > fails else "fail")
    split = bool(passes and fails)
    row = {"at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
           "case": case.get("id"), "output_sha": hashlib.sha256(output.encode()).hexdigest()[:12],
           "verdict": verdict, "split": split, "votes": votes}
    os.makedirs(os.path.dirname(os.path.abspath(args.log)), exist_ok=True)
    with open(args.log, "a") as f:
        f.write(json.dumps(row) + "\n")
    if verdict is None:
        print("judges: fewer than two judges answered: "
              + "; ".join(f"{v['judge']}: {v['problem']}" for v in votes if v["problem"]), file=sys.stderr)
        return 1
    if split:
        print("SPLIT")
    print(verdict)
    return 0


if __name__ == "__main__":
    sys.exit(main())
