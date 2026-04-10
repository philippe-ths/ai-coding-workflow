# AI Workflow

Version: 1.0.0

This file defines the workflow for AI-assisted coding on this project.
It is written for the AI coding agent.
The human reviews and approves at defined checkpoints.

## First Principles

- The codebase provides implementation truth.
- Runtime behaviour is the final source of truth.

## Workflow

1. **Confirm the task and inputs.**

   - Confirm the GitHub issue number.
   - Read the issue and its comments.
   - Check branch state.
   - See [GitHub Workflow](#github-workflow).
   - Rebase onto the target branch.
   - Run baseline validation.
   - See [Validation Requirements](#validation-requirements).
   - Confirm the task is a bounded change.
   - See [Scope Control](#scope-control).
   - Complete this step before analysing implementation details.

2. **Review project context.**

   - Read relevant project files.
   - Review the code areas the task is likely to touch.
   - Extract the intended outcome from the issue before using implementation suggestions. (Why: Issue text is often stale or speculative; treating implementation suggestions as authoritative causes the agent to implement the wrong thing.)

3. **Produce a code-aware plan.**

   - See [Planning Requirements](#planning-requirements).

4. **Checkpoint: human reviews the plan.**

   - Update the plan if the human requests changes.

5. **Implement the approved scope.**

   - Implement the work defined in the approved plan.
   - See [Implementation Rules](#implementation-rules).
   - See [Scope Control](#scope-control).

6. **Run validation.**

   - Run validation checks.
   - See [Validation Requirements](#validation-requirements).

7. **Support manual verification.**

   - Suggest manual checks for the human.
   - See [Manual Verification Requirements](#manual-verification-requirements).

8. **Checkpoint: human reviews validation results and manual verification.**

9. **Fix and revalidate.**

   - Fix reported issues.
   - Rerun relevant validation checks after each fix.
   - Repeat until no issues remain.
   - Enter [Failure Analysis Mode](#failure-analysis-mode) if a fix fails.
   - Enter [Failure Analysis Mode](#failure-analysis-mode) if manual verification fails.

10. **Summarise and prepare handoff.**

    - Report what changed.
    - Report what was tested.
    - Report what was not tested.
    - Report remaining risks and follow-up work.
    - State which GitHub action would be next if the human wants to publish the work.
    - See [GitHub Workflow](#github-workflow).

11. **Checkpoint: human approves the next GitHub action.**

    - Stop after the summary until the human explicitly approves the next GitHub action in the current session.

12. **Run the approved GitHub action and stop.**

    - Run only the single GitHub action the human explicitly approved.
    - See [GitHub Workflow](#github-workflow).

## Planning Requirements

When producing a plan:

- State the branch the work will be implemented on.
- State the goal of the change in one or two sentences.
- State the user-visible behaviour that must change.
- State the files and code areas the change will touch.
- State the proposed implementation approach.
- State assumptions and classify each as issue-sourced (unverified) or codebase-confirmed (verified by reading the code).
- State how each issue-sourced assumption will be verified.
- If a codebase-confirmed assumption turns out to be wrong during implementation, stop and revise the plan.
- State remaining uncertainties, risks, and edge cases.
- Mark the change as higher-risk if it affects routing, persistence, sync, caching, reactive subscriptions, or state transitions.
- Include at least one runtime validation step for higher-risk changes.
- State the validation approach.
- Keep the plan concise.
- Do not include implementation detail that belongs in the code.
- Do not restate the issue verbatim.
- Treat the issue goal as authoritative but treat implementation suggestions as provisional until the codebase confirms them.
- If the issue and the current codebase disagree, prioritise the codebase and flag the mismatch to the human.

## Implementation Rules

During implementation:

- Prefer extending current patterns over introducing new ones. (Why: New patterns increase review surface, reduce predictability, and create maintenance drift.)
- Keep changes focused and relevant to the approved plan.

## Scope Control

Keep the change focused on the approved task:

- If the issue contains multiple unrelated objectives, flag this and ask the human whether to split them into separate tasks.
- If the task would require changes across many unrelated areas of the codebase, flag the risk and suggest decomposition.
- Do only the work required to complete the task.
- Do not treat "while I am here" changes as free. (Why: Each unplanned change introduces untested risk and dilutes commit traceability.)
- Separate fixes, refactors, and feature work unless the task clearly requires them together. (Why: Mixing change types obscures the commit's intent and makes review harder.)
- If a larger problem is discovered, flag it as follow-up work instead of silently broadening the implementation. (Why: Unreviewed scope expansions break the human approval model and introduce unvalidated changes.)

## Validation Requirements

Before implementation, run a baseline validation:

1. Run smoke tests.
2. Run the global test suite.
3. Record which tests pass and which tests fail.
4. Treat any pre-existing failure as a known failure for the duration of the task.
5. Do not attempt to fix pre-existing failures unless the task requires it.

When comparing post-implementation results against the baseline:

- If a test that passed in the baseline now fails, treat the change as wrong until proven otherwise.
- If a test that failed in the baseline still fails, do not attribute it to the change.
- Report pre-existing failures separately from change-related failures.

Run validation after every code change.
Run the following checks in order:

1. **Smoke tests.**
   - Confirm the app builds and starts without errors.

2. **Global test suite.**
   - Run the full existing test suite.

3. **Targeted tests.**
   - Run tests specific to the changed area.
   - If no targeted tests exist, flag this.

4. **New tests.**
   - Add tests if the change introduces behaviour that existing tests do not cover.
   - Run the new tests.

When running validation:

- Do not modify smoke tests or the global test suite unless the task explicitly requires it.
- Run smoke tests and the global test suite after each meaningful implementation pass.
- Treat existing passing tests as evidence of stability, not proof of correctness for new behaviour.
- If the change affects state transitions, sync, routing, caching, or reactive UI updates, include validation that follows the full user path.
- If no automated test exercises the real user path, say so explicitly.
When reporting validation:

- Report what was tested and what passed.
- Report what failed and whether the failure is related to the change.
- Report what was not tested and why.
- Do not claim code is tested when it is not.
- Do not ignore failing tests and continue as if the task is complete.

## Manual Verification Requirements

When supporting manual verification:

- Suggest specific manual checks based on the change.
- State the success signal for each check.
- State the failure signal for each check.

## Failure Analysis Mode

Enter failure analysis mode when manual verification fails.
Enter failure analysis mode when runtime behaviour contradicts the implementation.
Enter failure analysis mode when test results conflict with observed behaviour.

When in failure analysis mode:

- Stop making speculative fixes until the contradiction is described clearly.
- Restate the contradiction: observed behaviour, expected behaviour, strongest conflicting evidence, and what remains unknown.
- List the assumptions the implementation relied on and mark each as verified, unverified, or disproved.
- List plausible failure causes across issue interpretation, code path, persistence, sync, caching, routing, UI binding, environment, and test coverage.
- Identify the cheapest next observation that can eliminate one or more hypotheses.
- Name the single leading hypothesis and its supporting evidence before proposing the next step.
- Gather evidence before proposing another fix.
- Test at least one concrete hypothesis before asking the human to retry.
- Prioritise code path, persistence, sync, routing, and UI binding explanations over environment or caching unless evidence shows otherwise.
- If investigation reveals the plan was based on incorrect assumptions, state what the plan assumed, what the codebase actually does, and what a revised approach needs.
- Signal a flawed approach only when evidence shows the assumptions were wrong, not based on difficulty alone.

## GitHub Workflow

Every task must follow the GitHub branching workflow:

- Link every task to a GitHub issue before implementation.
- Do not work directly on `main`.
- If the current branch is `main`, stop before implementation and create or switch to an issue-scoped branch.
- Do not edit files, run issue validation, or make commits until the issue-scoped branch is active.
- Use the branch naming format `type/short-description` (`feature/`, `fix/`, `refactor/`).
- Keep branch work focused on the issue scope.
- Rebase the issue branch onto the target branch before starting implementation.
- Rebase the issue branch onto the target branch before creating a pull request.
- If new commits have landed on the target branch since the last rebase, rebase again before the next remote GitHub action.
- If a rebase produces modify/delete conflicts, stop and discuss with the human before resolving.
- If the task changes significantly during implementation, update the issue or flag the mismatch to the human.
- Treat commit creation, push to remote, and pull request creation as separate GitHub actions.
- Do not push to remote without explicit human confirmation in the current session.
- Do not create a pull request without explicit human confirmation in the current session.
- Do not infer approval for one GitHub action from approval for another.
- After running an approved GitHub action, stop and report the result.

## Boundary Rules

### Always Do

The following apply to every task without exception:

- ALWAYS follow the workflow steps in order.
- ALWAYS stop and ask when anything is unclear, risky, or out of scope.
- ALWAYS flag uncertainty, guessed behaviour, and incomplete validation explicitly.
- ALWAYS stop and ask the human before continuing if two commands in a row do not reduce uncertainty.
- ALWAYS state what a command does and why before requesting approval to run it.

### Ask First

Stop and ask the human before doing any of the following:

- ASK before adding a new dependency.
- ASK before changing architecture or established patterns.
- ASK before changing database schema or sync-related behaviour.
- ASK before changing public interfaces or shared contracts.
- ASK before making broad refactors.
- ASK before deleting files or removing significant code paths.
- ASK before running `git reset --hard` or any command that discards uncommitted working-tree state.
- ASK before weakening, skipping, or removing tests.
- ASK before introducing new conventions or changing existing ones.
- ASK before introducing a new logging library or pattern.
- ASK before making assumptions where the task or expected behaviour is unclear.
- ASK before proceeding when the work conflicts with the current codebase or project constraints.

### Never Do

Do not do any of the following under any circumstances:

- NEVER invent requirements not present in the task or project context.
- NEVER silently expand scope or introduce unrelated changes.
- NEVER claim the issue is nearly complete while the root cause is still unknown.
- NEVER hardcode sensitive values.
