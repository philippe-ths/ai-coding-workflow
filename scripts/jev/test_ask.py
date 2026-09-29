"""Offline test for the Jev question tool.

Run directly: `python3 scripts/jev/test_ask.py` (exits non-zero on failure).
Also invoked by scripts/repo-validation.sh. Never touches the network: the HTTP
layer (urllib.request.urlopen) or the one network call (ask.post) is replaced.
"""

import io
import json
import os
import sys
import tempfile
import time
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ask  # noqa: E402

failures = []
STATE_MARKER = "zebra-quartz-marker"
KEY = "test-key-7f3a"


def check(name, got, want):
    if got != want:
        failures.append(f"{name}: got {got!r}, want {want!r}")


def score_response(probs, confidence):
    return {
        "model": "jev-test",
        "answers": {"q": {
            "type": "score",
            "score": sum(int(k) * v for k, v in probs.items()),
            "legend": {"0": "a", "1": "b", "2": "c"},
            "probabilities": probs,
            "confidence": confidence,
        }},
        "usage": {"input_tokens": 10, "output_tokens": 1},
    }


def with_question(overrides, fn):
    """Run fn with the ceremony question file's fields replaced."""
    original = ask.load_question
    ask.load_question = lambda name: ({**original("ceremony")[0], **overrides}, "v")
    try:
        return fn()
    finally:
        ask.load_question = original


class FakeHTTP:
    """Stands in for urlopen: replays a list of outcomes (dict body or exception)."""

    def __init__(self, outcomes):
        self.outcomes, self.calls = list(outcomes), 0

    def __call__(self, req, timeout):
        self.calls += 1
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        body = json.dumps(outcome).encode()
        return type("Resp", (), {"__enter__": lambda s: s, "__exit__": lambda s, *a: False,
                                 "read": lambda s: body})()


def http_error(code):
    return urllib.error.HTTPError(ask.ENDPOINT, code, "x", {}, None)


def main(tmp):
    os.environ["AIW_JEV_LOG"] = os.path.join(tmp, "runs.jsonl")
    os.environ["TYPESAFE_API_KEY"] = KEY
    real_post = ask.post
    outputs = []

    # Every shipped question must load and carry a level name per Score criterion,
    # or interpret() would mislabel answers.
    for name in ask.list_questions():
        q, _ = ask.load_question(name)
        if q["question"]["type"] == "score":
            check(f"{name} levels match criteria", len(q["levels"]), len(q["question"]["criteria"]))

    # The request carries the question file's question and the model; structured state
    # passes through as an object.
    sent = []
    ask.post = lambda body, key: sent.append((body, key)) or score_response({"0": 0.1, "1": 0.1, "2": 0.8}, 0.7)
    code, result = ask.ask("ceremony", json.dumps({"title": STATE_MARKER, "body": "b"}))
    outputs.append(result)
    check("answered exit", code, ask.EXIT_OK)
    check("request question", sent[-1][0]["questions"]["q"], ask.load_question("ceremony")[0]["question"])
    check("request model", sent[-1][0]["model"], ask.MODEL)
    check("state passed as object", sent[-1][0]["state"], {"title": STATE_MARKER, "body": "b"})
    check("key sent", sent[-1][1], KEY)
    check("probabilities named", sorted(result["probabilities"]), ["full", "light", "standard"])

    # The level is the most likely one, not the rounded mean; an exact tie goes to the heavier level.
    ask.post = lambda body, key: score_response({"0": 0.5, "1": 0.0, "2": 0.5}, 0.9)
    check("split is not the middle; tie goes heavier", ask.ask("ceremony", "x")[1]["answer"], "full")
    ask.post = lambda body, key: score_response({"0": 0.2, "1": 0.7, "2": 0.1}, 0.9)
    check("top level named", ask.ask("ceremony", "x")[1]["answer"], "standard")

    # act follows the threshold, inclusive, and is never true without one.
    for conf, want in ((0.8, True), (0.79, False)):
        ask.post = lambda body, key, c=conf: score_response({"0": 1.0, "1": 0.0, "2": 0.0}, c)
        got = with_question({"act_above": 0.8}, lambda: ask.ask("ceremony", "x")[1]["act"])
        check(f"act at confidence {conf}", got, want)
    ask.post = lambda body, key: score_response({"0": 1.0, "1": 0.0, "2": 0.0}, 1.0)
    check("no act without threshold", with_question({"act_above": None}, lambda: ask.ask("ceremony", "x")[1]["act"]), False)

    # Noul and Choice answers.
    for p, want in ((0.9, 0.8), (0.1, 0.8), (0.5, 0.0)):
        ask.post = lambda body, key, p=p: {"answers": {"q": {"type": "noul", "noul": p}}, "usage": "odd"}
        r = with_question({"act_above": 0.7}, lambda: ask.ask("ceremony", "x")[1])
        check(f"noul {p} confidence", round(r["confidence"], 6), want)
    # The choice is Jev's pick, which need not be the highest listed probability after rounding.
    ask.post = lambda body, key: {"answers": {"q": {"type": "choice", "choice": "a",
                                                    "probabilities": {"a": 0.4, "b": 0.6}, "confidence": 0.6}}}
    r = ask.ask("ceremony", "x")[1]
    check("choice answer", (r["answer"], r["confidence"]), ("a", 0.6))

    # Malformed responses are unavailable, never a traceback.
    for label, response in (
        ("no q", {"answers": {}}),
        ("noul without value", {"answers": {"q": {"type": "noul"}}}),
        ("empty probabilities", score_response({}, 0.9)),
        ("level out of range", score_response({"3": 1.0}, 0.9)),
        ("no confidence", {"answers": {"q": {"type": "score", "score": 0, "probabilities": {"0": 1.0}}}}),
        ("unknown type", {"answers": {"q": {"type": "other"}}}),
        ("negative level", score_response({"-1": 1.0}, 0.9)),
        ("confidence not a number", score_response({"0": 1.0}, float("nan"))),
        ("not an object", ["answers"]),
    ):
        ask.post = lambda body, key, r=response: r
        check(f"malformed: {label}", ask.ask("ceremony", "x")[0], ask.EXIT_UNAVAILABLE)

    # Anything unexpected past the usage checks is unavailable, and leaks neither state nor key.
    def boom(body, key):
        raise RuntimeError(f"{STATE_MARKER} {key}")
    ask.post = boom
    code, r = ask.ask("ceremony", STATE_MARKER)
    outputs.append(r)
    check("unexpected error is unavailable", code, ask.EXIT_UNAVAILABLE)

    # The HTTP layer: busy statuses retry, others do not, and transport failures are unavailable.
    ask.post = real_post
    real_urlopen, real_delays = ask.urllib.request.urlopen, ask.RETRY_DELAYS
    ask.RETRY_DELAYS = (0, 0)
    try:
        ok = score_response({"0": 1.0, "1": 0.0, "2": 0.0}, 1.0)
        for label, outcomes, want_code, want_calls in (
            ("busy then answered", [http_error(529), http_error(429), ok], ask.EXIT_OK, 3),
            ("busy throughout", [http_error(529)] * 3, ask.EXIT_UNAVAILABLE, 3),
            ("bad key not retried", [http_error(401), ok], ask.EXIT_UNAVAILABLE, 1),
            ("network down", [urllib.error.URLError("down")], ask.EXIT_UNAVAILABLE, 1),
            ("truncated body", [ask.http.client.IncompleteRead(b"")], ask.EXIT_UNAVAILABLE, 1),
        ):
            fake = FakeHTTP(outcomes)
            ask.urllib.request.urlopen = fake
            check(f"http: {label}", (ask.ask("ceremony", "x")[0], fake.calls), (want_code, want_calls))
    finally:
        ask.urllib.request.urlopen, ask.RETRY_DELAYS = real_urlopen, real_delays

    # A call that outlives the deadline is unavailable, and returns at the deadline.
    ask.post, real_deadline = (lambda body, key: time.sleep(2)), ask.DEADLINE_SECONDS
    ask.DEADLINE_SECONDS = 0.2
    started = time.monotonic()
    check("deadline", ask.ask("ceremony", "x")[0], ask.EXIT_UNAVAILABLE)
    check("deadline returns promptly", time.monotonic() - started < 1, True)
    ask.DEADLINE_SECONDS = real_deadline

    # Keys: none at all, then one read from the key file.
    os.environ["TYPESAFE_API_KEY"] = ""
    os.environ["AIW_JEV_KEY_FILE"] = os.path.join(tmp, "missing")
    check("no key", ask.ask("ceremony", "x")[0], ask.EXIT_UNAVAILABLE)
    key_file = os.path.join(tmp, "key")
    with open(key_file, "w") as fh:
        fh.write(f"  {KEY}\n")
    os.environ["AIW_JEV_KEY_FILE"] = key_file
    ask.post = lambda body, key: sent.append((body, key)) or score_response({"0": 1.0, "1": 0.0, "2": 0.0}, 1.0)
    ask.ask("ceremony", "x")
    check("key file read and stripped", sent[-1][1], KEY)

    # Usage errors, including a name that tries to leave questions/.
    check("unknown question", ask.ask("no-such-question", "x")[0], ask.EXIT_USAGE)
    check("path as question", ask.ask("../questions/ceremony", "x")[0], ask.EXIT_USAGE)
    check("empty state", ask.ask("ceremony", "  \n")[0], ask.EXIT_USAGE)

    # The command line: --state-file in either position, and an unreadable file is a usage error.
    state_file = os.path.join(tmp, "state.json")
    with open(state_file, "w") as fh:
        fh.write('{"title": "t"}')
    quiet = io.StringIO()
    real_stdout, real_stderr, sys.stdout, sys.stderr = sys.stdout, sys.stderr, quiet, io.StringIO()
    try:
        check("cli state-file after", ask.main(["ask.py", "ceremony", "--state-file", state_file]), ask.EXIT_OK)
        check("cli state-file before", ask.main(["ask.py", "--state-file", state_file, "ceremony"]), ask.EXIT_OK)
        check("cli missing file", ask.main(["ask.py", "ceremony", "--state-file", os.path.join(tmp, "nope")]), ask.EXIT_USAGE)
        check("cli stdin", ask.main(["ask.py", "ceremony"], stdin=io.StringIO("fix a typo")), ask.EXIT_OK)
        binary = type("In", (), {"isatty": lambda s: False, "buffer": io.BytesIO(b"\xff\xfe")})()
        check("cli non-UTF-8 stdin", ask.main(["ask.py", "ceremony"], stdin=binary), ask.EXIT_USAGE)
        tty = type("In", (), {"isatty": lambda s: True})()
        check("cli terminal stdin", ask.main(["ask.py", "ceremony"], stdin=tty), ask.EXIT_USAGE)
    finally:
        sys.stdout, sys.stderr = real_stdout, real_stderr
    outputs.append(quiet.getvalue())

    # The log records outcomes and never the state or the key; neither does any output.
    with open(os.environ["AIW_JEV_LOG"]) as fh:
        log = fh.read()
    check("log rows written", log.count("\n") > 10, True)
    check("state never logged", STATE_MARKER in log, False)
    check("key never logged", KEY in log, False)
    check("key never printed", KEY in json.dumps(outputs), False)

    if failures:
        print("jev ask test: FAIL", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        sys.exit(1)
    print("jev ask test: OK")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        main(tmp)
