"""Let Jev sit on the judge panel: read the panel's prompt on stdin, print PASS or FAIL.

Jev takes a state and a fixed question, not a free prompt, so this passes it only
the rule and the output from the prompt and asks the `eval-judge` question. When
Jev is unsure its likeliest level is still its vote; the panel's majority and the
split flag are what absorb an unsure judge.

Exit codes: 0 a vote was printed, 3 Jev is unavailable (no key, network), 2 the
prompt held no rule and output.
"""

import json
import os
import re
import subprocess
import sys

ASK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "jev", "ask.py")


def main():
    prompt = sys.stdin.read()
    rule = re.search(r"<rule>\n(.*?)\n</rule>", prompt, re.S)
    output = re.search(r"<output>\n(.*)\n</output>", prompt, re.S)
    if not rule or not output:
        print("jev_vote: no <rule> and <output> in the prompt", file=sys.stderr)
        return 2
    state = json.dumps({"rule": rule.group(1), "output": output.group(1)})
    done = subprocess.run([sys.executable, ASK, "eval-judge"], input=state, capture_output=True, text=True)
    if done.returncode != 0:
        print(f"jev_vote: {done.stdout.strip() or done.stderr.strip()}", file=sys.stderr)
        return done.returncode
    answer = json.loads(done.stdout)
    vote = answer.get("answer") or answer.get("lean")
    print(f"Jev: {json.dumps(answer.get('probabilities'))}, confidence {answer.get('confidence')}")
    print(vote.upper())
    return 0


if __name__ == "__main__":
    sys.exit(main())
