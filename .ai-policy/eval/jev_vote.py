"""Let Jev sit on the judge panel: read the panel's prompt on stdin, print PASS or FAIL.

Jev takes a state and a fixed question, not a free prompt, so this passes it only
the rule and the output from the prompt and asks the `eval-judge` question. Jev
answers with a probability for each level. Below SURE its likeliest level is close
to a coin toss, and a coin toss on a panel of three manufactures a split, so it
abstains and leaves the verdict to the other judges.

Exit codes: 0 a vote was printed, 3 Jev is unavailable (no key, network), 2 the
prompt held no rule and output.
"""

import json
import os
import re
import subprocess
import sys

SURE = 0.75  # the probability Jev must give its likeliest level before that level is a vote
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
    print(vote_from(answer))
    return 0


def vote_from(answer):
    probabilities = answer.get("probabilities") or {}
    vote = answer.get("answer") or answer.get("lean")
    sure = probabilities.get(vote, 0) >= SURE
    return f"Jev: {json.dumps(probabilities)}\n{vote.upper() if sure else 'ABSTAIN'}"


if __name__ == "__main__":
    sys.exit(main())
