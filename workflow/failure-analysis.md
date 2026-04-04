# Failure Analysis Mode

Read this file when entering failure analysis mode.
Enter failure analysis mode when manual verification fails, when runtime behaviour contradicts the implementation, or when test results conflict with observed behaviour.
This file contains the full process for investigating and resolving those contradictions.

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
