# AI Workflow

Version: 2.6.0

This file defines the workflow for AI-assisted coding on this project.
It is written for the AI coding agent.
The human reviews and approves at defined checkpoints.

## First Principles

- The codebase provides implementation truth.
- Runtime behaviour is the final source of truth.

## Workflow

The workflow runs as a loop.
Steps 5 through 9 form an implementation cycle: implement, validate, and fix until the human approves.
Steps 10 through 13 form a handoff cycle: summarise, check readiness, get approval, and run one GitHub action at a time.
After the human merges the pull request, run post-merge cleanup and return to Step 1 for the next task.

1. **Step 1: Confirm the task and inputs.**

   - Confirm the GitHub issue number.
   - Read the issue.
   - See [Handling Parent and Sub-Issues](#handling-parent-and-sub-issues).
   - Check branch state.
   - Check the branch is up to date with the target branch.
   - See [GitHub Workflow](#github-workflow).
   - Run baseline validation.
   - See [Validation Requirements](#validation-requirements).
   - Check test readiness.
   - See [Test Readiness](#test-readiness).
   - Confirm the task is a bounded change.
   - See [Scope Control](#scope-control).
   - If the GitHub issue number, issue context, active branch, or baseline validation state is missing or unclear, stop and resolve before proceeding.

2. **Step 2: Review project context.**

   - Review `project-context.md` for project structure, constraints, and domain context relevant to the task.
   - Review the code areas the task is likely to touch.
   - Extract the intended outcome from the issue.

3. **Step 3: Produce a code-aware plan.**

   - See [Planning Requirements](#planning-requirements).

4. **Checkpoint 4: human reviews the plan.**

   - Update the plan if the human requests changes.
   - See [Planning Requirements](#planning-requirements) for handling human feedback.

5. **Step 5: Implement the approved scope.**

   - Implement the work defined in the approved plan.
   - See [Implementation Rules](#implementation-rules).
   - See [Scope Control](#scope-control).

6. **Step 6: Run validation.**

   - Run validation checks.
   - See [Validation Requirements](#validation-requirements).

7. **Step 7: Support manual verification.**

   - Suggest manual checks for the human.
   - See [Manual Verification Requirements](#manual-verification-requirements).

8. **Checkpoint 8: human reviews validation results and manual verification.**

9. **Step 9: If the human reports issues, fix and revalidate.**

   - Fix reported issues.
   - Rerun relevant validation checks after each fix.
   - Return to Step 5 if further implementation is needed, or Step 6 if only validation is needed.
   - If a fix fails or manual verification fails, enter [Failure Analysis Mode](#failure-analysis-mode).

10. **Step 10: Summarise.**

    - Report what changed.
    - Report what was tested.
    - Report what was not tested.
    - Report remaining risks and follow-up work.

11. **Step 11: Pre-PR readiness check.**

    - Complete all readiness checks before proposing the first remote GitHub action.
    - If follow-up issues need to be created, load the `aiw-issue-creation` skill.
    - Flag if documentation or README files need updating based on the change.
    - Flag if version numbers need updating.
    - Flag if a tagged release is needed.
    - Check parent and sub-issue closure status.
    - See [Handling Parent and Sub-Issues](#handling-parent-and-sub-issues).
    - State which GitHub action would be next if the human wants to publish the work.
    - See [GitHub Workflow](#github-workflow).

12. **Checkpoint 12: human approves the next GitHub action.**

    - Stop after the summary until the human explicitly approves the next GitHub action in the current session.

13. **Step 13: Run the approved GitHub action and stop.**

    - Run only the single GitHub action the human explicitly approved.
    - See [GitHub Workflow](#github-workflow).
    - If the human approves another GitHub action, return to Step 12.

14. **Step 14: Post-merge cleanup.**

    - Check whether the local issue branch has unmerged commits before deleting it.
    - Switch to the main branch.
    - Pull latest changes from remote.
    - Close the GitHub issue.
    - If the issue uses checkboxes, check off completed items.
    - Comment on the issue with key findings or direction changes.
    - Return to Step 1 for the next task, or end the session.

## Planning Requirements

Use when executing Step 3 (Produce a code-aware plan) or Checkpoint 4 (human reviews the plan).
Do not produce a plan without loading this skill first.

Load the `aiw-planning` skill.

## Implementation Rules

During implementation:

- Use `project-context.md` for initial context on architectural patterns, project structure, and conventions.
- Prefer extending current patterns over introducing new ones. (Why: New patterns increase review surface, reduce predictability, and create maintenance drift.)
- Keep changes focused and relevant to the approved plan.

## Scope Control

Keep the change focused on the approved task:

- If the issue contains multiple unrelated objectives, flag this and ask the human whether to split them into separate tasks.
- If the task would require changes across many unrelated areas of the codebase, flag the risk and suggest decomposition.
- Extract the intended outcome from the issue before using implementation suggestions.
  (Why: Issue text is often stale or speculative; treating implementation suggestions as authoritative leads to implementing the wrong thing.)
- Do only the work required to complete the task.
- Do not treat "while I am here" changes as free. (Why: Each unplanned change introduces untested risk and dilutes commit traceability.)
- Separate fixes, refactors, and feature work unless the task clearly requires them together. (Why: Mixing change types obscures the commit's intent and makes review harder.)
- If a larger problem is discovered, flag it as follow-up work instead of silently broadening the implementation. (Why: Unreviewed scope expansions break the human approval model and introduce unvalidated changes.)
- If the human approves, load the `aiw-issue-creation` skill to create the follow-up issue.
- If the task changes significantly during implementation, update the issue or flag the mismatch to the human.

## Validation Requirements

Before implementation, run a baseline validation:

1. Run smoke tests and the global test suite.
2. Record which tests pass and which tests fail.
3. Treat pre-existing failures as known for the task's duration.
4. Do not fix pre-existing failures unless the task requires it.

When comparing post-implementation results against the baseline:

- If a test that passed in the baseline now fails, treat the change as wrong until proven otherwise.
- If a test that failed in the baseline still fails, do not attribute it to the change.

After each code change, run the following checks in order:

1. **Smoke tests.** Confirm the app builds and starts without errors.
2. **Global test suite.** Run the full existing test suite.
3. **Targeted tests.** Run tests specific to the changed area.
   - If no targeted tests exist, flag this.
4. **New tests.** Add tests if the change introduces behaviour that existing tests do not cover.
   - See [Writing Tests](#writing-tests).
   - If a new test fails, use the failure output to guide the next implementation change before rerunning.

If repo-local deterministic policy requires a passed validation state before commit or push, satisfy that requirement through the repository validation flow.

When running validation:

- Do not modify smoke tests or the global test suite unless the task explicitly requires it.
- Do not run validation commands in parallel when they can share ports, build outputs, caches, or runtime state.
- Do not treat passing smoke tests and the global test suite as proof that the requested behaviour works.
- If the change affects state transitions, sync, routing, caching, or reactive UI updates, include validation that follows the full user path.
- If no automated test exercises the real user path, say so explicitly.

When reporting validation:

- Report what was tested, what passed, what failed (and whether change-related), and what was not tested.
- Do not ignore failing tests or claim code is tested when it is not.

## Test Readiness

Check test readiness during Step 1, after baseline validation.

1. Check whether the project has smoke tests that confirm the app builds and starts.
2. Check whether the project has a test suite with at least one passing test.
3. Check whether tests exist for the code area the task will touch.

If any of these are missing, flag the gap to the human before proceeding.
Do not write tests to fill the gap unless the human approves.

If the task is specifically about writing tests, skip this check.

## Writing Tests

Use when the plan includes writing new tests.
Use when Step 6 identifies missing test coverage.
Use when the task is specifically about creating tests.

Load the `aiw-testing` skill.

## Manual Verification Requirements

Manual verification covers what only a human can verify.

- Suggest checks that require human observation: visual behaviour, user experience flows, real-device interaction, external system responses.
- Do not suggest checks that can be verified through automated tests or tool output.
- State the success signal for each check.
- State the failure signal for each check.

## Failure Analysis Mode

Enter failure analysis mode when manual verification fails, runtime behaviour contradicts the implementation, or test results conflict with observed behaviour.
Do not make further code changes until failure analysis is complete.

Load the `aiw-failure-analysis` skill.

## Logging and Observability

Use when the change modifies runtime behaviour that automated tests cannot fully validate.
Use when existing logging is insufficient to diagnose a failure.

Load the `aiw-logging-and-observability` skill.

## Project Context Management

Use when creating `project-context.md` for the first time.
Use when updating `project-context.md` after routes, schema, sync rules, dependencies, project structure, or test coverage have changed.

Load the `aiw-project-context-management` skill.

## Command Approval

When requesting approval to run a command:

- State what the command does.
- State why the command needs to run.

## GitHub Workflow

Every task must follow the GitHub branching workflow:

- Link every task to a GitHub issue before implementation.
- Do not work directly on `main`.
- Create or switch to an issue-scoped branch before editing files or making commits.
- Use the branch naming format `type/short-description`.
- Rebase the issue branch onto the target branch before starting implementation and before creating a pull request.
- If new commits have landed on the target branch since the last rebase, rebase again before the next remote GitHub action.
- Before any operation that moves the working tree to a different branch state (rebase, checkout, switch), compare tracked files between the current branch and the target.
- Before the same operation, check whether gitignored or untracked local files exist at paths the target state tracks.
- If either check reveals unexpected files or path overlap, stop and report before proceeding.
- If the human approves, back up the working tree (excluding `.git/`) before the operation.
- Delete the backup after confirming no files were lost.
- If a rebase produces modify/delete conflicts, stop and discuss with the human before resolving.
- Treat commit creation, push to remote, and pull request creation as separate GitHub actions.
- Do not infer approval for one GitHub action from approval for another.
- Do not push to remote or create a pull request without explicit human confirmation in the current session.
- If Git `core.hooksPath` is not `.githooks`, run `./.ai-policy/scripts/install-hooks.sh`.
- If deterministic policy blocks an action, fix the blocked condition before retrying.
- If new commits are added after approval, stop and ask again before the next remote GitHub action.
- After running an approved GitHub action, stop and report the result.

## Handling Parent and Sub-Issues

For every issue:

- Read the issue comments for clarifications, scope changes, and constraints not in the original body.

When the issue has sub-issues (it is a parent):

- Treat the parent issue as broader context, not as a work item.
- Do not implement the full parent scope.
- Stop and ask which sub-issue to work on.

When the issue is a sub-issue:

- Read the direct parent issue and its comments for context.
- Do not read further up the hierarchy.
- Implement only the sub-issue scope.
- When completing the sub-issue, check whether it is the last open sub-issue under the parent.
- If it is the last open sub-issue, flag this to the human.

## Boundary Rules

### Always Do

The following apply to every task without exception:

- ALWAYS follow the workflow steps in order.
- ALWAYS stop and ask when anything is unclear, risky, or out of scope.
- ALWAYS flag uncertainty, guessed behaviour, and incomplete validation explicitly.
- ALWAYS stop and ask the human before continuing if two commands in a row do not reduce uncertainty.

### Ask First

Stop and ask the human before doing any of the following:

- ASK before adding a new dependency.
- ASK before changing architecture, established patterns, or conventions.
- ASK before changing database schema, sync behaviour, public interfaces, or shared contracts.
- ASK before making broad refactors.
- ASK before deleting files or removing significant code paths.
- ASK before running `git reset --hard` or any command that discards uncommitted working-tree state.
- ASK before weakening, skipping, or removing tests.

### Never Do

Do not do any of the following under any circumstances:

- NEVER invent requirements not present in the task or project context.
- NEVER silently expand scope or introduce unrelated changes.
- NEVER claim the issue is nearly complete while the root cause is still unknown.
- NEVER hardcode sensitive values.
- NEVER bypass deterministic policy checks or treat them as optional.

## The Human is Responsible For

The AI cannot perform these tasks.
The human must complete them.

- Define and scope the task before it reaches the AI.
- Decompose larger work into sub-issues and provide a sub-issue rather than the parent as the starting input.
- Provide a well-formed GitHub issue as the starting input.
- Ensure the right project context is available.
- Review and approve the plan before coding starts.
- Monitor for scope drift during implementation.
- Perform manual verification where automated tests are not sufficient.
- Report issues found during review or testing.
- Merge pull requests.
- Communicate the intent of issues clearly when delegating issue creation.
- Decide when the work is complete.
