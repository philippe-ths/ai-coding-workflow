"""Ask Jev one named question about a piece of state and print a typed answer.

Usage:
  python3 scripts/jev/ask.py <question> [--state-file PATH]   (state on stdin otherwise)
  python3 scripts/jev/ask.py --list

Each question is a file in scripts/jev/questions/<name>.json holding the Jev
question, its level names, and `act_above`: the confidence at or above which the
answer may be acted on without a second opinion (null until measured). Adding a
question means adding a file; nothing here changes.

Prints one JSON object on stdout. Exit codes:
  0  answered
  2  usage error (unknown question, empty or unreadable state)
  3  unavailable (no key, network, service busy after retries, bad response, deadline)
Unavailable is never an error for the caller to fix: it means "decide without me".

The key comes from TYPESAFE_API_KEY, else ~/.typesafe_key (AIW_JEV_KEY_FILE overrides
the path). Every call that gets past usage checks appends one row to
~/.claude/aiw-jev/runs.jsonl (AIW_JEV_LOG overrides) recording the answer and its
cost, never the state itself.
"""

import datetime
import hashlib
import http.client
import json
import math
import os
import re
import sys
import threading
import time
import urllib.error
import urllib.request

ENDPOINT = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-latest"
TIMEOUT_SECONDS = 10
DEADLINE_SECONDS = 20
RETRY_STATUSES = (429, 529)
RETRY_DELAYS = (0.5, 1.5)
QUESTIONS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "questions")
QUESTION_NAME = re.compile(r"^[a-z0-9][a-z0-9_-]*$")

EXIT_OK, EXIT_USAGE, EXIT_UNAVAILABLE = 0, 2, 3


class Unavailable(Exception):
    pass


def list_questions():
    return sorted(f[:-5] for f in os.listdir(QUESTIONS_DIR) if f.endswith(".json"))


def load_question(name):
    # A name is a file in questions/, never a path: the file's contents are sent with the key.
    path = os.path.join(QUESTIONS_DIR, f"{name}.json")
    if not QUESTION_NAME.match(name) or not os.path.isfile(path):
        return None, None
    with open(path, "rb") as fh:
        raw = fh.read()
    question = json.loads(raw)
    if not isinstance(question, dict) or not isinstance(question.get("question"), dict):
        raise ValueError("question file has no question object")
    return question, hashlib.sha256(raw).hexdigest()[:12]


def read_key():
    key = os.environ.get("TYPESAFE_API_KEY", "").strip()
    if key:
        return key
    path = os.environ.get("AIW_JEV_KEY_FILE") or os.path.expanduser("~/.typesafe_key")
    try:
        with open(path) as fh:
            return fh.read().strip() or None
    except (OSError, ValueError):
        return None


def parse_state(text):
    # Structured state reads better to the model than a JSON string, so pass objects through.
    try:
        value = json.loads(text)
    except ValueError:
        return text
    return value if isinstance(value, (dict, list)) else text


def build_request(question, state):
    return {"state": state, "model": MODEL, "questions": {"q": question["question"]}}


def post(body, key):
    """The one network call. Tests replace this function."""
    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    for attempt in range(len(RETRY_DELAYS) + 1):
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code in RETRY_STATUSES and attempt < len(RETRY_DELAYS):
                time.sleep(RETRY_DELAYS[attempt])
                continue
            raise Unavailable(f"HTTP {e.code}")
        except (urllib.error.URLError, http.client.HTTPException, OSError, ValueError) as e:
            raise Unavailable(type(e).__name__)
    raise Unavailable("retries exhausted")


def post_within_deadline(body, key):
    # The socket timeout bounds each read, not the call: a server dripping bytes could hold
    # the caller for minutes. The deadline bounds the whole call, retries included.
    box = {}

    def run():
        try:
            box["response"] = post(body, key)
        except Exception as e:  # anything post raises is carried back, never lost in the thread
            box["error"] = e

    worker = threading.Thread(target=run, daemon=True)
    worker.start()
    worker.join(DEADLINE_SECONDS)
    if worker.is_alive():
        raise Unavailable("deadline")
    if "error" in box:
        e = box["error"]
        raise e if isinstance(e, Unavailable) else Unavailable(type(e).__name__)
    return box["response"]


def interpret(question, response):
    """Turn Jev's answer into what callers use: a named level or choice, and whether to act on it."""
    try:
        return _interpret(question, response)
    except (KeyError, TypeError, ValueError, IndexError, AttributeError):
        raise Unavailable("malformed response")


def _interpret(question, response):
    answer = response["answers"]["q"]
    kind = answer["type"]
    out = {"type": kind}
    if kind == "noul":
        p = finite(answer["noul"])
        out["noul"] = p
        # A Noul has no confidence; distance from 0.5 is the only honest proxy.
        out["confidence"] = abs(p - 0.5) * 2
    elif kind == "choice":
        out["answer"] = answer["choice"]
        out["probabilities"] = answer["probabilities"]
        out["confidence"] = finite(answer["confidence"])
    elif kind == "score":
        probs = answer["probabilities"]
        levels = question.get("levels")
        # The most likely level, not the rounded mean: a split between the two ends is not the
        # middle. An exact tie goes to the later level, since levels run from least to most.
        n = len(levels) if levels else len(answer["legend"])
        if not probs or any(not k.isdigit() or int(k) >= n for k in probs):
            raise ValueError("level out of range")
        top = max(probs, key=lambda k: (finite(probs[k]), int(k)))
        out["answer"] = levels[int(top)] if levels else answer["legend"][top]
        out["score"] = answer["score"]
        out["probabilities"] = {(levels[int(k)] if levels else k): v for k, v in probs.items()}
        out["confidence"] = finite(answer["confidence"])
    else:
        raise ValueError(kind)
    threshold = question.get("act_above")
    out["act"] = threshold is not None and out["confidence"] >= threshold
    return out


def log_run(row):
    path = os.environ.get("AIW_JEV_LOG") or os.path.expanduser("~/.claude/aiw-jev/runs.jsonl")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a") as fh:
            fh.write(json.dumps(row) + "\n")
    except OSError:
        pass  # a log that cannot be written must not cost the caller its answer


def ask(name, state_text):
    """Returns (exit_code, result_dict)."""
    try:
        question, version = load_question(name)
    except (OSError, ValueError):
        return EXIT_USAGE, {"error": f"question {name!r} is not readable JSON"}
    if question is None:
        return EXIT_USAGE, {"error": f"unknown question {name!r}", "questions": list_questions()}
    if not state_text.strip():
        return EXIT_USAGE, {"error": "empty state"}

    row = {
        "at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "question": name,
        "question_version": version,
        "state_sha256": hashlib.sha256(state_text.encode(errors="replace")).hexdigest()[:16],
        "state_chars": len(state_text),
    }
    started = time.monotonic()
    key = read_key()
    try:
        if not key:
            raise Unavailable("no API key")
        response = post_within_deadline(build_request(question, parse_state(state_text)), key)
        result = interpret(question, response)
        usage_info = response.get("usage")
        input_tokens = usage_info.get("input_tokens") if isinstance(usage_info, dict) else None
    except Exception as e:
        # The contract is exit 3, never a traceback: callers decide without the answer.
        e = e if isinstance(e, Unavailable) else Unavailable(type(e).__name__)
        row.update(outcome="unavailable", reason=str(e), latency_ms=int((time.monotonic() - started) * 1000))
        log_run(row)
        return EXIT_UNAVAILABLE, {"question": name, "unavailable": str(e)}

    result = {"question": name, "question_version": version, "model": response.get("model"), **result}
    row.update(
        outcome="answered",
        model=result["model"],
        answer=result.get("answer", result.get("noul")),
        confidence=result["confidence"],
        act=result["act"],
        latency_ms=int((time.monotonic() - started) * 1000),
        input_tokens=input_tokens,
    )
    log_run(row)
    return EXIT_OK, result


def finite(x, low=0.0, high=1.0):
    x = float(x)
    if not (math.isfinite(x) and low <= x <= high):
        raise ValueError(x)
    return x


def usage():
    print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
    return EXIT_USAGE


def main(argv, stdin=sys.stdin):
    args = argv[1:]
    if args == ["--list"]:
        print(json.dumps(list_questions()))
        return EXIT_OK
    state_file = None
    if "--state-file" in args:
        i = args.index("--state-file")
        if i + 1 >= len(args):
            return usage()
        state_file = args[i + 1]
        args = args[:i] + args[i + 2:]
    if len(args) != 1:
        return usage()
    if state_file is not None:
        try:
            with open(state_file) as fh:
                state_text = fh.read()
        except (OSError, ValueError) as e:
            print(json.dumps({"error": f"cannot read state file: {type(e).__name__}"}))
            return EXIT_USAGE
    elif stdin.isatty():
        # Waiting on a terminal for state nobody will type is a hang, not a question.
        return usage()
    else:
        try:
            state_text = stdin.buffer.read().decode() if hasattr(stdin, "buffer") else stdin.read()
        except ValueError as e:
            print(json.dumps({"error": f"cannot read state: {type(e).__name__}"}))
            return EXIT_USAGE
    code, result = ask(args[0], state_text)
    print(json.dumps(result))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
