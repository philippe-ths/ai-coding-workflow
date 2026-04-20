---
name: aiw-failure-analysis
description: "Structured investigation for when the user reports something is broken or not working, especially after tests passed or a fix was applied. Trigger phrases include 'still broken', 'still doesn't work', 'still fails', 'didn't help', 'didn't work', 'the bug remains', 'not working', 'doing the wrong thing'. Other triggers: tests pass but the user reports the feature is broken; a fix did not resolve the behaviour; a user report contradicts validation output; runtime behaviour contradicts the implementation or plan; manual verification fails. Load on any of these conditions before proposing a fix. The skill forces a structured pause to acknowledge the gap between agent expectations and user reality, then investigate before changing more code."
---

# Failure Analysis Mode

Read this file when entering failure analysis mode.
This file contains the full process for investigating and resolving contradictions between your expectations and user-observed reality.

## Why This Mode Exists

When tests pass and validation succeeds, you believe the implementation is correct. If the user then reports that the feature is broken or the app doesn't work, there is a gap between your understanding and reality. Your natural response is to jump to the nearest quick fix — but if your understanding of the system was wrong enough for the tests to miss the problem, a quick fix is likely to be wrong too. This mode forces a structured pause: stop, describe the contradiction, list what could be wrong, and gather evidence before writing more code.

## Related Workflow Sections

This skill works alongside these workflow sections — consult them during investigation:

- **Validation Requirements** — understand what validation should have caught; compare post-change results against the baseline.
- **Logging and Observability** — load the `aiw-logging-and-observability` skill when diagnostic approaches are needed during investigation.

## Process

When in failure analysis mode:

- Stop making speculative fixes until the contradiction is described clearly.
- State the observed behaviour in user terms.
- State the expected behaviour in user terms.
- Restate the contradiction in one short block before any reasoning.
- Use this format: observed behaviour, expected behaviour, strongest conflicting evidence, and what remains unknown.
- List the assumptions the implementation relied on.
- Mark each assumption as verified, unverified, or disproved.
- List plausible failure causes across issue interpretation, code path selection, persistence, sync, caching, routing, UI binding, environment, test coverage, and observability.
- Identify the cheapest next observation that can eliminate one or more hypotheses.
- If multiple hypotheses exist, prefer the next observation that distinguishes between wrong code path, wrong write, later overwrite, sync overwrite, and stale runtime.
- Name the single leading hypothesis before proposing the next step.
- State the evidence that currently supports the leading hypothesis.
- If repeated fixes under different hypotheses are not converging, state this clearly.
- If investigation reveals that the plan was based on incorrect assumptions about the codebase, state this clearly.
- Report what the plan assumed.
- Report what the codebase actually does.
- Report what a revised approach would need to account for.
- If the contradiction involves a write, state transition, sync boundary, or reactive screen, prefer temporary diagnostics or direct observation over a retry request.
- Gather evidence before proposing another fix.
- Test at least one concrete hypothesis before asking the human to retry the flow, refresh the app, clear cache, restart the dev server, or repeat manual verification.
- Prioritise code path, persistence, sync, routing, and UI binding explanations over environment or caching unless evidence shows otherwise.
- Do not signal a flawed approach based on difficulty alone. (Why: Difficulty is normal implementation friction; only evidence of wrong assumptions signals a flawed approach.)
- Signal a flawed approach only when evidence shows the assumptions were wrong.
