# AI Workflow

This file defines the workflow for AI-assisted coding on this project.
It is written for the AI coding agent.
The human reviews and approves at defined checkpoints.

## First Principles

- The codebase provides implementation truth.
- Runtime behaviour is the final source of truth.

## Workflow

1. **Confirm the task and inputs.**
   - Confirm the GitHub issue number and read the issue and its comments.
   - If the issue has a parent issue or sub-issues, see [Handling Parent and Sub-Issues](#handling-parent-and-sub-issues).
   - Confirm the current branch is not `main` and the branch name is relevant to the issue. See [GitHub Workflow](#github-workflow).
   - Confirm the task is clear enough to define a bounded change.
   - If the issue contains multiple unrelated objectives, flag this and ask the human whether to address them as separate tasks.
   - If the task scope is large enough that completing it would require working across many unrelated areas of the codebase, flag the risk and suggest decomposition.
   - Complete all checks in this step before analysing issue content, comments, or linked issues.

2. **Review project context.**
   - Read `project-spec.md` and any files relevant to the task.
   - Review the areas of the codebase the task is likely to touch.
   - Extract the intended outcome from the issue before using any implementation suggestions.
   - Verify all issue-suggested implementation details against the current codebase before relying on them.
   - See [Planning Requirements](#planning-requirements) for rules on handling issue vs codebase disagreements.

3. **Produce a code-aware plan.**
   - Write the plan.
   - See [Planning Requirements](#planning-requirements).

4. **Checkpoint: human reviews the plan.**
   - Update the plan if the human requests changes.

5. **Implement the approved scope.**
   - Implement the work defined in the approved plan.
   - See [Implementation Rules](#implementation-rules) and [Scope Control](#scope-control).

6. **Run validation.**
   - Run validation checks.
   - See [Validation Requirements](#validation-requirements).
   - Report results clearly.

7. **Support manual verification.**
   - Suggest specific things the human should verify, based on the change.
   - When suggesting manual checks, include the exact success signal and the exact failure signal.

8. **Checkpoint: human reviews validation results and runs manual verification.**
   - Stop and wait for the human to confirm before continuing, even if the change appears trivial.

9. **Fix and revalidate.**
   - Fix reported issues.
   - Rerun relevant validation checks after each fix.
   - Repeat until no issues remain.
   - If a fix fails or manual verification fails, enter [Failure Analysis Mode](#failure-analysis-mode).

10. **Summarise and close.**
    - Report: what changed, what was tested, what was not tested, and any remaining risks or follow-up work.
    - Flag any follow-up work the change surfaced but that is out of scope.
    - If this is the last open sub-issue under a parent issue, flag this to the human.
    - Suggest creating a pull request when the work appears complete, but wait for the human to confirm before proceeding.

## Planning Requirements

Before implementation, produce a plan that includes:

- The goal of the change in one or two sentences.
- The user-visible behaviour that must change, not only the code changes proposed.
- The files and areas of the codebase the change will touch.
- The proposed implementation approach.
- Any assumptions the plan depends on.
- List the assumptions that come from the issue separately from assumptions confirmed in the codebase.
- For each critical assumption, state how it will be verified.
- Any uncertainties or ambiguities that remain.
- Risks and edge cases.
- If the change affects routing, persistence, sync, caching, reactive subscriptions, or state transitions, mark it as a higher-risk change.
- For higher-risk changes, include at least one runtime validation step that proves the intended user behaviour.
- Validation approach.
  See [Validation Requirements](#validation-requirements).
- Any logging or observability changes needed.
  See [Logging and Observability](#logging-and-observability).

When writing the plan:

- Treat the issue goal as authoritative, but treat suggested implementation details as provisional until confirmed against the current codebase.
- Do not assume the files, data flow, or control points named in the issue are the real execution path.
- If the issue and the current codebase disagree, prioritise the codebase and flag the mismatch to the human.
- If the issue suggests a structure that the current codebase does not follow, plan against the real structure and flag the mismatch.
- Keep the plan concise.

## Implementation Rules

During implementation:

- Use `project-spec.md` as the reference for architectural patterns, project structure, and conventions.
- Prefer extending current patterns over introducing new ones.
- Keep changes focused and relevant to the approved plan.

## Scope Control

Keep the change focused on the approved task:

- Do only the work required to complete the task.
- Do not treat "while I am here" changes as free.
- Separate fixes, refactors, and feature work unless the task clearly requires them together.
- If a larger problem is discovered, flag it as a follow-up instead of silently broadening the implementation.

## Validation Requirements

Run the following checks after every code change, in order:

1. **Smoke tests.** Confirm the app builds and starts without errors.
2. **Global test suite.** Run the full existing test suite.
   Report any failures, including failures unrelated to the change.
3. **Targeted tests.** Run tests specific to the changed area.
   If no targeted tests exist, flag this.
4. **New tests.** If the change introduces behaviour that is not covered by existing tests, add tests.
   Run them and report results.

When running validation:

- Do not modify smoke tests or the global test suite unless the task explicitly requires it.
- If a test that was passing before the change fails after it, the change is wrong, not the test.
- Run smoke tests and the global test suite after each meaningful implementation pass, not only at the end of the task.
- Do not treat passing smoke tests and the global test suite as proof that the requested behaviour works.
- Treat existing passing tests as evidence of stability, not proof of correctness for the new behaviour.
- When the change affects state transitions, sync, routing, caching, or reactive UI updates, include validation that follows the full user path.
- If no automated test exercises the real user path, say so explicitly.
- If manual verification fails, stop implementation mode and enter [Failure Analysis Mode](#failure-analysis-mode) before making more code changes.

Report clearly:

- What was tested and what passed.
- What failed and whether the failure is related to the change.
- What was not tested and why.

## Failure Analysis Mode

Enter failure analysis mode when manual verification fails, runtime behaviour contradicts the implementation, or test results conflict with observed behaviour.

When in failure analysis mode:

- Stop making speculative fixes until the contradiction is described clearly.
- State the observed behaviour in user terms.
- State the expected behaviour in user terms.
- Restate the contradiction in one short block before any reasoning.
- Use the format: observed behaviour, expected behaviour, strongest conflicting evidence, and what remains unknown.
- List the assumptions the implementation relied on.
- Mark each assumption as verified, unverified, or disproved.
- List plausible failure causes across issue interpretation, code path selection, persistence, sync, caching, routing, UI binding, environment, test coverage, and observability.
- Identify the cheapest next observation that can eliminate one or more hypotheses.
- When multiple hypotheses exist, prefer the next observation that distinguishes between wrong code path, wrong write, later overwrite, sync overwrite, and stale runtime.
- Before proposing the next step, name the single leading hypothesis and the evidence that currently supports it.
- If repeated fixes under different hypotheses are not converging, or if investigation reveals the plan was based on incorrect assumptions about the codebase, state this clearly.
  Report what the plan assumed, what the codebase actually does, and what a revised approach would need to account for.
- If the contradiction involves a write, state transition, sync boundary, or reactive screen, prefer temporary diagnostics or direct observation over a retry request.
- Gather evidence before proposing another fix.
- Do not ask the human to retry the flow, refresh the app, clear cache, restart the dev server, or repeat manual verification until at least one concrete hypothesis has been tested with new evidence.
- Do not treat environment or caching as the leading explanation unless evidence makes it more likely than code path, persistence, sync, routing, or UI binding failures.
- Do not signal a flawed approach based on difficulty alone.
  Signal it only when evidence shows the assumptions were wrong.

## Logging and Observability

Consider whether additional logging or observability is needed when the change introduces user-facing flows, data writes, sync operations, state transitions, error handling paths that could fail silently, or integration points between layers.

When adding logging:

- Use the project's existing logging approach.
  If none exists, flag this in the plan.
- Log the action, relevant identifiers, and outcome (success or failure).
- Include enough context to trace a problem without a debugger.
- Do not add logging for trivial operations or where it would expose sensitive user data.
- Do not log full data payloads unless explicitly needed.
- When a change affects writes, sync behaviour, state transitions, or reactive screens, decide explicitly whether temporary diagnostic logging is needed to verify the runtime path.
- Prefer logs or probes that confirm which code path executed, which identifiers were used, and which state transition occurred.
- If observability is too weak to distinguish between competing hypotheses, flag that before continuing.
- Remove temporary diagnostics before completion unless the human approves keeping them.
- For higher-risk changes, if manual verification fails and the runtime path is not yet proven, decide whether temporary diagnostics or another direct observation method is needed before asking the human to retry.

When investigating root causes or verifying runtime behaviour, prefer automated diagnostics over asking the human to observe and report:

- Write diagnostics that capture structured, non-sensitive output such as event types, state changes, control flow decisions, and timestamps.
- Run the diagnostic, read the results, and use them to drive the next step without waiting for human involvement.
- If a diagnostic cannot avoid capturing sensitive data, do not write it.
  Describe what to look for and let the human observe it directly.
- Only ask the human to provide logs or reproduce behaviour when automated observation is not possible.
- If the condition can only be triggered by the human, ask the human to trigger it and provide the raw output.
  Do not ask the human to interpret the results.

## GitHub Workflow

Every task must follow the GitHub branching workflow:

- Every task must be linked to a GitHub issue.
- Do not work directly on `main`.
- Create a branch for the issue before starting work.
- If the branch name does not match the issue or task, stop and create or switch to an appropriate branch before continuing.
- Branch naming format: `type/short-description`. Use `feature/` for new functionality, `fix/` for bug fixes, `refactor/` for refactors.
- Keep branch work focused on the issue scope.
- If the task changes significantly during implementation, update the issue or flag the mismatch.

## Handling Parent and Sub-Issues

Some work may be organised into parent issues and sub-issues in GitHub.
When this structure is used:

- A parent issue provides broader context and may list sub-issues.
- A sub-issue is a single bounded work item.
- If the provided issue is a parent issue with sub-issues, do not implement the full parent scope.
  Stop and ask which sub-issue to work on.
- If the provided issue is a sub-issue, read the parent issue and its comments for context.
  Do not read further up the hierarchy.
  Implement only the sub-issue scope.
- If the provided issue has no sub-issues, treat it as a standalone work item.
- When completing a sub-issue, check whether it is the last open sub-issue under the parent.
  If it is, flag this to the human.

## Boundary Rules

### Always Do

The following apply to every task without exception:

- Run validation after every code change, not only at the end of the task.
  See [Validation Requirements](#validation-requirements).
- Report test results honestly, including failures unrelated to the change.
- Stop and ask when anything is unclear, risky, or out of scope.
- When requesting approval to run a command, state what the command does and why it needs to run, not only the command itself.

### Ask First

Stop and ask the human before doing any of the following:

- Adding a new dependency.
- Changing architecture or established patterns.
- Changing database schema or sync-related behaviour.
- Changing public interfaces or shared contracts.
- Making broad refactors.
- Deleting files or removing significant code paths.
- Weakening, skipping, or removing tests.
- Introducing new conventions or changing existing ones.
- Introducing a new logging library or pattern.
- Making assumptions where the task or expected behaviour is unclear.
- Proceeding when the work conflicts with the current codebase or project constraints.

### Never Do

Do not do any of the following under any circumstances:

- Skip, reorder, or combine workflow steps.
- Work directly on `main`.
- Implement without a confirmed issue number.
- Invent requirements not present in the task or project context.
- Silently expand scope or introduce unrelated changes.
- Claim code is tested when it is not.
- Ignore failing tests and continue as if the task is complete.
- Hide uncertainty, guessed behaviour, or incomplete validation.
- Claim the issue is nearly complete while the root cause is still unknown.
- Push to remote or create a pull request without explicit human confirmation.
- Write diagnostics that output sensitive data, including tokens, credentials, PII, full payloads, or anything that could identify a real user.
- Hardcode sensitive values.

## The Human is Responsible For

The AI cannot perform these tasks.
They must be completed by the human.

- Defining and scoping the task before it reaches the AI.
- Decomposing larger work into sub-issues and providing a sub-issue (not the parent) as the starting input.
- Providing a well-formed GitHub issue as the starting input.
- Ensuring the right project context is available.
- Reviewing and approving the plan before coding starts.
- Monitoring for scope drift during implementation.
- Performing manual verification where automated tests are not sufficient.
- Reporting issues found during review or testing.
- Deciding when the work is complete.