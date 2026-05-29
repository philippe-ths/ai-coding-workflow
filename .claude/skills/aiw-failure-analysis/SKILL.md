---
name: aiw-failure-analysis
description: "Reactive skill for when the agent has claimed a task complete and that claim is contradicted by the user, by runtime behaviour, or by manual verification. Use it whenever the user reports the behaviour is still broken, the fix didn't help, the system is doing the wrong thing, or runtime disagrees with the agent's tests or validation, with phrases like 'still broken' or 'didn't help'. Load this skill BEFORE proposing any fix. The trigger is a trust collapse: the three core skills (aiw-ground-truth, aiw-testing, aiw-verification) that should have caught the problem did not, so the agent cannot trust its oracle, tests, or verification until each is audited. It stops the agent jumping to the nearest plausible patch. It owns the structured pause after a contradicted 'done' claim, the audit of the three core skills, the hypothesis-and-evidence loop that replaces speculative fixing, the convergence check when repeated fixes fail, and the plan-level flaw detection path."
---

# Failure Analysis

Read this file the moment a "done" claim is contradicted. Read it before any further code change, any retry request, and any "let me try X" suggestion.

## Why This Skill Exists

When the agent declared the task complete, three things had to have signed off: the oracle was right, the tests passed, and verification concluded the change worked. If reality now disagrees, at least one of those three was wrong — and the agent has no immediate way to know which, because the agent was the actor in all three roles.

This is a trust collapse. The agent's natural response is to jump to the nearest plausible fix. Resist it. If understanding was wrong enough for verification to miss the problem, the nearest plausible fix is likely also wrong, and a sequence of such fixes will produce confident-looking patches that move the broken behaviour around without resolving it.

This skill is reactive. The three core skills (aiw-ground-truth, aiw-testing, aiw-verification) are proactive — they keep the loop honest. This skill runs when the loop failed anyway, and audits the three core skills to find where the gap opened.

## Relationship to the Investigate Modality

The Investigate modality (defined in aiw-ground-truth) covers tasks where producing understanding is the deliverable from the start — diagnosing a bug, narrowing down a cause, deciding what to build. Failure analysis covers tasks where the agent thought it had finished and was wrong. The investigative posture is the same; the trigger is different. Failure analysis runs the audit specific to a contradicted "done" claim, then typically hands off to a fresh task — often in Fix or Investigate modality — that goes through the three core skills normally.

## The Hard Stop

Until the audit below has run, do not:

- Write more code.
- Propose another fix.
- Ask the user to refresh, retry, restart, clear cache, restart the dev server, or repeat manual verification.
- Suggest "let me try X" as the next step.

This is non-negotiable. The agent has no current basis for trusting its next attempt. Run the audit first.

## Describe the Contradiction

Before any reasoning, produce a short structured block. Four parts:

- **Observed behaviour.** In user terms. What is actually happening.
- **Expected behaviour.** In user terms. What should be happening.
- **Strongest conflicting evidence.** The single piece of evidence that most clearly contradicts the agent's "done" claim.
- **What remains unknown.** What the agent does not yet have evidence about.

State the gap before theorising about it. This discipline keeps the rest of the analysis grounded in the contradiction itself rather than in the agent's preferred explanation.

## Audit the Three Core Skills

The heart of this skill. The agent answers three audits in order, with specific answers. Vague answers ("the oracle was probably fine", "tests covered most of it") are not acceptable — they are the failure mode that produced the contradicted "done" claim. If an answer cannot be made specific, that itself is a finding.

### Ground truth audit

- What did the work treat as the oracle?
- Which trust level did each fixture or expected output sit at, per aiw-ground-truth's trust hierarchy?
- Were any fixtures synthetic? If so, did the modality require a higher trust level?
- Was the oracle confirmed by the user, or invented by the agent?
- Was the oracle the right one for the modality the task was classified under?
- Could the oracle itself have been wrong?

### Verification audit

The verification audit examines aiw-verification's three-part justification as a structured artifact, asking whether each part held up against the contradiction.

**Part 1 — what could plausibly have broken.**

- Did the justification name the surface that actually broke?
- If not, why was that surface missed?

**Part 2 — what evidence shows it did not break.**

- What was the evidence, in terms of aiw-verification's evidence hierarchy?
- Was end-to-end execution on real ground-truth artifacts run where the modality required it?
- Did the evidence actually cover the surface that broke?

**Part 3 — what was not checked.**

- Was the unverified surface named, or hidden?
- Did the named unverified surface include the area that turned out to be wrong?

### Testing audit

- Were there tests covering the broken behaviour? If yes, why did they pass while the behaviour was broken? Were they running against synthetic fixtures? Were they asserting on implementation details rather than observable behaviour? Were they mocking the thing they were supposed to test?
- If no tests covered the broken behaviour, why did the verification step not flag that gap?
- Are existing tests independent and able to fail when the code is broken, or could a green bar be deceptive?

If the audit identifies a specific gap — a synthetic fixture used where a real one was required, an end-to-end run skipped, a test mocking the boundary it was meant to exercise, an unverified surface that was hidden rather than named — name the gap explicitly before moving on. The gap is the lead, not the symptom.

## List Assumptions

List the assumptions the implementation relied on. Mark each:

- **Verified.** Confirmed by direct observation of the code, runtime, or user statement.
- **Unverified.** Assumed without evidence; could be wrong.
- **Disproved.** Now known to be wrong in light of the contradiction.

Unverified and disproved assumptions are leads. Verified ones can be set aside.

## Plausible Failure Causes

Enumerate the categories of cause, not a list of speculations. Use these categories:

- **Issue interpretation.** The agent solved a different problem than the one being reported.
- **Code path selection.** The change touched code that does not run in the affected scenario.
- **Data flow between components.** The change is locally correct but the value is overwritten, transformed, or never reaches the place it needs to.
- **Persistence.** The change wrote, did not write, or wrote the wrong thing to storage.
- **Caching.** A stale value is being read instead of the new one.
- **External system interaction.** The change is correct against the agent's model of the external system but not against the real system.
- **Environment.** Configuration, secrets, or runtime differences between where it was tested and where it failed.
- **Test coverage.** The change is correct in the path tested but breaks an adjacent path that was not.
- **Observability.** The behaviour appears wrong because a log, metric, or display is wrong; the underlying behaviour is correct.

Examples of category-specific signals for the codebase at hand — UI rebind drift, sync overwrite, routing mismatch, write-then-read race, debounce swallowing input — fit under these categories rather than living as separate items in a project-agnostic list. Where a project has a well-known recurring failure mode, treat it as an example of one of the categories above.

## Cheapest Distinguishing Observation

Identify the single next observation that would eliminate the most hypotheses at the lowest cost. This is one of the strongest disciplines in failure analysis: a small, well-chosen observation collapses the space faster than a series of speculative fixes.

Prefer observations that distinguish between fundamentally different causes (wrong code path vs wrong write vs later overwrite vs stale read) rather than observations that confirm a specific theory the agent already prefers.

## Leading Hypothesis With Evidence

After the audit, the assumptions list, and the cause categories, name **one** leading hypothesis. Not a list of three. The output of analysis is a commitment to test, not an enumeration.

State the evidence that currently supports the hypothesis. If the evidence is thin, say so — that is part of calibration, not weakness.

## No Retry Requests Before Evidence

Do not ask the user to refresh, retry, restart, clear cache, restart the dev server, or repeat manual verification until at least one concrete hypothesis has been tested by direct observation of code, runtime output, logs, or stored state.

When the contradiction involves a write, a state transition, an external integration, or a piece of UI driven by reactive data, prefer temporary diagnostics or direct observation over a retry request. Retry requests in those cases produce more cycles of the same uncertainty rather than evidence.

Temporary diagnostics added during the audit (additional logging, probes, traces) must be removed before the work is declared complete, unless the human explicitly approves keeping them.

## Convergence Check

If repeated fixes under different hypotheses have not resolved the contradiction, that is itself evidence — not that the next hypothesis will be the one, but that the approach is wrong. State this clearly when it happens.

Three signals that the approach is wrong:

- Fixes change the symptom without resolving it.
- New fixes break things that previously worked.
- Each hypothesis sounds plausible until tested, then fails the same way.

When the convergence check fires, escalate to plan-level flaw detection below.

## Plan-Level Flaw Detection

The most important escalation path this skill provides. Make it visible, not implicit.

If the audit or the convergence check reveals that the original plan was based on incorrect assumptions about the codebase or the system being integrated with, the response is not another fix. It is a re-plan. Report to the user:

- **What the plan assumed.** The specific assumption about the codebase, the data flow, the external system, or the user's intent.
- **What the codebase or system actually does.** The observed reality that contradicts the assumption.
- **What a revised approach would need to account for.** Not a full new plan — a statement of the constraints a new plan would have to respect.

Hand the work back. A new plan, validated through aiw-planning and the three core skills from the start, is the correct response. Patching forward from a flawed plan compounds the error.

Do not signal a flawed approach based on difficulty alone. (Why: difficulty is normal implementation friction; only evidence of wrong assumptions signals a flawed approach.) Signal the flaw when the evidence shows the assumptions were wrong.

## Exit Condition

This skill's job is done when:

- The contradiction has been described.
- The three-skill audit has produced specific answers.
- Assumptions have been classified.
- A single leading hypothesis is named with supporting evidence.
- A concrete next step is identified.

The next step is typically a fresh task — Fix or Investigate modality — that runs through the three core skills normally. This skill is the place where the right next step is identified, not where the fix is written. Hand off to the new task at this point.

If the audit produces work that should be tracked separately — a coverage gap, a deeper bug surfaced by the investigation, a plan-level rework — use aiw-issue-creation to create the new issue. Do not bundle unrelated work into the current task.

## Anti-Patterns

- **Jumping to a speculative fix before describing the contradiction.** The contradiction must be stated structurally before reasoning about it; jumping skips the only part of the process that grounds the rest.
- **Asking the user to retry, refresh, or repeat the flow before testing a hypothesis.** Retry without evidence produces more cycles of the same uncertainty.
- **Producing a list of possible causes and treating that as the output.** Analysis ends in a commitment, not an enumeration. A list of three hypotheses without ranking is a failure to analyse.
- **Treating the audit as a formality.** Vague audit answers ("ground truth was probably fine") are the same posture that produced the contradicted claim. Specific answers or it is not an audit.
- **Continuing to iterate on fixes when nothing is converging.** Three plausible-but-failed hypotheses is evidence, not a coincidence. Name the convergence failure.
- **Patching the symptom without checking for a plan-level flaw.** If the audit reveals the plan was based on wrong assumptions about the codebase or system, no patch under the same plan will be correct. Escalate, do not patch.
