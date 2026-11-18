# Controlled evals of one change, alongside descriptive observation

**Status:** accepted

ADR 0001 removed the statistical version-comparison stack because comparing sparse real sessions across repositories never produced a trustworthy verdict. That reasoning stands, and so does the observation tool. But it left the workflow with no way to answer a narrower question that keeps arising: does this one change to a prompt, skill, rule or model step do what it is meant to? Answered by a single run, or by an eval the changing agent designed and scored alone, that question was answered wrongly four times running. We are adding a controlled eval of one change: old against new on the same varied cases, against a bar written before the first run, scored by code or by judges from other providers, run through a harness whose gates cannot be skipped. It returns one of three verdicts: works, does not work, or cannot be tested this way.

This is not the stack ADR 0001 removed. That stack compared whole workflow versions using whatever sessions happened to occur; this tests one change on cases built for it, in clean context, and says before spending when a question cannot be answered that way.

## Considered options

- **Rules in the testing and verification skills** telling the agent to treat a model-driven result as a rate. Tried on #432 and dropped: prose describing a method thrashed under review, and an agent following it still chose the wrong thing to measure.
- **Gates in code, with a short skill** (chosen). The order of the steps, the lock on the eval, and the check of the scorer are enforced by the harness; the skill holds only the judgement the harness cannot make, chiefly what to count.

## Consequences

- The human confirms one sentence, what is counted, with a passing and a failing example. They rule on at most five outputs, and only when the judges split and the verdict turns on it.
- Judged outputs leave the machine for the judges' providers. The harness replaces the human's email, name and home path before an output is saved or judged.
- Behaviour that only appears in long sessions under pressure cannot be staged. For those the answer is "cannot be tested this way", and the observation tool remains the only evidence.
- A verdict says the change does what was counted on these cases. It does not say the thing counted was the right goal; that rests on the human's one-sentence check.
