# Line-by-Line Rationale — AI Workflow Design Decisions

Covers the rationale for every line in `ai-workflow.md`.

## Line-by-Line Rationale for ai-workflow.md

Every line from `ai-workflow.md` is listed below with its rationale.

---

### Preamble

> "This file defines the workflow for AI-assisted coding on this project."

Rationale: Establishes the file's purpose so both human maintainers and AI agents know what they are reading.

> "It is written for the AI coding agent."

Rationale: Sets the audience explicitly. The human does not need to read this during a task; it exists to instruct the agent.

> "The human reviews and approves at defined checkpoints."

Rationale: Establishes the human-in-the-loop model upfront. The agent works; the human approves at defined gates.

---

### First Principles

> "The codebase provides implementation truth."

Rationale: Prevents the agent from trusting documentation, issue descriptions, or its own prior assumptions over what the code actually does. When ambiguous, the agent should read the code, not re-read the issue or guess from file names.

> "Runtime behaviour is the final source of truth."

Rationale: If the code says one thing and runtime says another, runtime wins. Prevents the agent from declaring a task complete because the code looks correct while the feature is actually broken.

---

### Workflow Step 1: Confirm the task and inputs

> "Confirm the GitHub issue number."

Rationale: Links every task to a trackable artifact. Without an issue number, there is no scope boundary and no audit trail.

> "Read the issue."

Rationale: The agent must understand what the task requires before doing any work. The issue is the primary input.

> "Check branch state."

Rationale: The agent must not work on a protected branch. Checking early prevents wasted work that has to be moved later.

> "Check the branch is up to date with the target branch."

Rationale: Working on a stale branch means writing code against an outdated state. Files may have moved, APIs may have changed, or new conflicts may have accumulated.

> "Run baseline validation."

Rationale: The rule "if a previously passing test fails after the change, treat the change as wrong" is unenforceable without a known-good baseline. The baseline distinguishes regressions from pre-existing failures.

> "Check test readiness."

Rationale: Baseline validation only catches regressions if meaningful tests exist. A project with no smoke tests or no test suite has no safety net, and this should be surfaced before starting work rather than discovered during validation.

> "Confirm the task is a bounded change."

Rationale: Unbounded tasks lead to scope drift. Confirming boundaries early forces the agent to flag multi-objective issues or overly broad tasks before starting.

> "If the GitHub issue number, issue context, active branch, or baseline validation state is missing or unclear, stop and resolve before proceeding."

Rationale: Prevents the agent from jumping into code analysis before confirming the task inputs are correct. Proceeding with missing inputs leads to wasted work on the wrong problem.

---

### Workflow Step 2: Review project context

> "Review `project-spec.md` for project structure, constraints, and domain context relevant to the task."

Rationale: The project spec provides architectural patterns, structure, and conventions. Reading it before planning prevents the agent from proposing changes that conflict with established patterns.

> "Review the code areas the task is likely to touch."

Rationale: The agent must verify that the code matches what the issue assumes. Issues are written against the author's mental model, which may be stale.

> "Extract the intended outcome from the issue."

Rationale: Separates the goal (what should change) from the means (how to change it). The detailed rule about handling implementation suggestions lives in Scope Control.

---

### Workflow Step 3: Produce a code-aware plan

Rationale: The plan exists as a checkpoint artifact that gives the human a concrete, reviewable description of what the agent intends to do before any code changes happen. The pointer to Planning Requirements keeps the workflow step lean.

---

### Workflow Checkpoint 4: Human reviews the plan

> "Update the plan if the human requests changes."

Rationale: The human checkpoint is a gate, not a formality. The agent must incorporate feedback rather than proceeding with the original plan.

---

### Workflow Step 5: Implement the approved scope

> "Implement the work defined in the approved plan."

Rationale: Scopes implementation to exactly what was approved. Prevents the agent from expanding scope during coding.

---

### Workflow Step 6: Run validation

> "Run validation checks."

Rationale: Validation after every code change catches regressions immediately. Deferring validation allows errors to compound.

---

### Workflow Step 7: Support manual verification

> "Suggest manual checks for the human."

Rationale: Automated tests cannot cover every user-facing path. The agent should identify what manual checks are needed and make them easy for the human.

---

### Workflow Checkpoint 8: Human reviews validation and manual verification

Rationale: Gate before the agent proceeds to fixes. The human may have observations the agent cannot detect.

---

### Workflow Step 9: Fix and revalidate

> "Fix reported issues."

Rationale: Directs the agent to address what the human identified during the checkpoint. Without this explicit instruction, the agent might only partially address feedback or prioritise easy fixes.

> "Rerun relevant validation checks after each fix."

Rationale: A fix can introduce new regressions. Re-validating after each fix prevents error compounding.

> "Return to Step 5 if further implementation is needed, or Step 6 if only validation is needed."

Rationale: Provides explicit routing for the fix loop. Without it, the agent may not know whether to re-implement or just re-validate, or may stop after one pass even when multiple issues were reported.

> "If a fix fails or manual verification fails, enter Failure Analysis Mode."

Rationale: Prevents the agent from cycling through speculative fixes. Manual verification failure means runtime contradicts the implementation. Forces structured reasoning before more code changes.

---

### Workflow Step 10: Summarise

> "Report what changed."

Rationale: Gives the human a clear picture of the implementation for review.

> "Report what was tested."

Rationale: Establishes what the agent has validated, so the human knows what is covered.

> "Report what was not tested."

Rationale: Honest reporting prevents the human from assuming full coverage when there are gaps.

> "Report remaining risks and follow-up work."

Rationale: The agent may have discovered problems outside the current scope. These should be surfaced, not silently dropped.

---

### Workflow Step 11: Pre-PR readiness check

> "Complete all readiness checks before proposing the first remote GitHub action."

Rationale: Makes the readiness gate explicit. When readiness checks were embedded in the summary step, agents treated the summary as complete once they had reported what changed and what was tested, then skipped the remaining checks and jumped to proposing a GitHub action.

> "If follow-up issues need to be created, load the `issue-creation` skill."

Rationale: Follow-up work identified during the task should be captured in structured issues rather than lost in conversation. The skill ensures consistent issue quality.

> "Flag if documentation or README files need updating based on the change."

Rationale: Code changes can make existing documentation inaccurate. Flagging this prevents documentation drift.

> "Flag if version numbers need updating."

Rationale: Some changes require version bumps. The agent should surface this for the human to decide.

> "Flag if a tagged release is needed."

Rationale: Release decisions belong to the human, but the agent should flag when a change warrants one.

> "Check parent and sub-issue closure status."

Rationale: Lets the human know whether completing this sub-issue closes the parent.

> "State which GitHub action would be next if the human wants to publish the work."

Rationale: Prepares the handoff. The agent proposes; the human decides.

---

### Workflow Checkpoint 12: Human approves the next GitHub action

> "Stop after the summary until the human explicitly approves the next GitHub action in the current session."

Rationale: Prevents the agent from pushing code or creating PRs based on momentum. Each remote action requires explicit consent.

---

### Workflow Step 13: Run the approved GitHub action and stop

> "Run only the single GitHub action the human explicitly approved."

Rationale: Prevents chaining (e.g. human approves a push, agent also creates a PR). Each action is a separate approval.

> "If the human approves another GitHub action, return to Step 12."

Rationale: Keeps the one-action-at-a-time model. The human can approve sequential actions, but each requires its own approval cycle.

---

### Workflow Step 14: Post-merge cleanup

> "Check whether the local issue branch has unmerged commits before deleting it."

Rationale: Prevents accidental loss of work that was not included in the merge.

> "Switch to the main branch."

Rationale: Returns the working tree to the shared branch so the next task starts from the correct base.

> "Pull latest changes from remote."

Rationale: Ensures the local main branch includes the just-merged changes and any other recent commits.

> "Close the GitHub issue."

Rationale: Marks the task as complete in the tracking system. Open issues with merged work create false signals about remaining work.

> "If the issue uses checkboxes, check off completed items."

Rationale: Keeps the issue's progress indicators accurate for anyone reviewing the issue history.

> "Comment on the issue with key findings or direction changes."

Rationale: Captures context that would otherwise be lost in the conversation. Future readers of the issue benefit from knowing what was discovered during implementation.

> "Return to Step 1 for the next task, or end the session."

Rationale: Closes the loop. The workflow is continuous until the human decides to stop.

---

### Planning Requirements

> "Use when executing Step 3 (Produce a code-aware plan) or Checkpoint 4 (human reviews the plan)."

Rationale: Scopes when the planning skill is relevant so the agent does not load it at other workflow steps.

> "Do not produce a plan without loading this skill first."

Rationale: The planning skill contains the detailed structure and rules for plans. Without it, the agent produces unstructured plans that are harder to review.

> "Load the `planning` skill."

Rationale: Extracts detailed planning rules to an on-demand skill to keep the core workflow lean and reclaim always-on context budget.

---

### Implementation Rules

> "Use `project-spec.md` for initial context on architectural patterns, project structure, and conventions."

Rationale: The project spec is the starting point for understanding the codebase. It prevents the agent from inventing patterns that conflict with existing ones.

> "Prefer extending current patterns over introducing new ones."

Rationale: New patterns increase cognitive load and review burden. Consistency is cheaper than novelty.

> "Keep changes focused and relevant to the approved plan."

Rationale: Scope control during implementation. The approved plan defines the boundary.

---

### Scope Control

> "If the issue contains multiple unrelated objectives, flag this and ask the human whether to split them into separate tasks."

Rationale: Agents tend to pick the easiest objective and declare progress, leaving harder objectives partially addressed. Splitting forces each objective to be tracked independently.

> "If the task would require changes across many unrelated areas of the codebase, flag the risk and suggest decomposition."

Rationale: Cross-cutting changes are harder to review, harder to test, and more likely to introduce regressions.

> "Extract the intended outcome from the issue before using implementation suggestions."

Rationale: Separates the goal (what should change) from the means (how to change it). The goal is authoritative; the implementation suggestions need verification against the current codebase. Issues are often stale or speculative.

> "Do only the work required to complete the task."

Rationale: The fundamental scope rule. Everything else in this section is a specific application of this principle.

> "Do not treat 'while I am here' changes as free."

Rationale: Agents optimise for perceived completeness, leading to unrequested refactors and cosmetic changes that increase review burden and risk.

> "Separate fixes, refactors, and feature work unless the task clearly requires them together."

Rationale: Mixing change types in one task makes review harder and makes it impossible to revert one type without reverting the others.

> "If a larger problem is discovered, flag it as follow-up work instead of silently broadening the implementation."

Rationale: Silently broadening scope is the most common agent failure mode. Flagging preserves scope while ensuring the problem is not lost.

> "If the human approves, load the `issue-creation` skill to create the follow-up issue."

Rationale: Provides the action path for flagged follow-up work. The skill ensures follow-up issues are well-formed rather than hastily written.

> "If the task changes significantly during implementation, update the issue or flag the mismatch to the human."

Rationale: The issue is the scope contract. If implementation diverges, the issue must be updated or the human must be informed so the scope contract stays accurate.

---

### Validation Requirements: Baseline

> "Run smoke tests." / "Run the global test suite."

Rationale: Establishes the known-good baseline before implementation. Without this, regressions cannot be distinguished from pre-existing failures.

> "Record which tests pass and which tests fail."

Rationale: The recorded baseline is the comparison point for post-implementation results.

> "Treat any pre-existing failure as a known failure for the duration of the task."

Rationale: Prevents wasted time debugging failures the change did not cause.

> "Do not attempt to fix pre-existing failures unless the task requires it."

Rationale: Fixing unrelated failures is scope drift and may introduce new problems.

> "If a test that passed in the baseline now fails, treat the change as wrong until proven otherwise."

Rationale: The default assumption should be that the change broke it. This prevents the agent from dismissing regressions.

> "If a test that failed in the baseline still fails, do not attribute it to the change."

Rationale: Pre-existing failures should not block the current task or trigger unnecessary debugging.

> "Report pre-existing failures separately from change-related failures."

Rationale: Mixed reporting makes it impossible for the human to assess the change's impact.

---

### Validation Requirements: Running validation

> "Run validation after every code change."

Rationale: Catching regressions immediately is cheaper than catching them after multiple changes have accumulated.

> "If repo-local deterministic policy requires a passed validation state before commit or push, satisfy that requirement through the repository validation flow."

Rationale: Connects the workflow instruction to the deterministic enforcement system. The agent should use the project's validation flow, not bypass it.

> "Confirm the app builds and starts without errors." (Smoke tests)

Rationale: The cheapest check. If the app does not build, nothing else matters.

> "Run the full existing test suite." (Global test suite)

Rationale: Catches regressions across the entire codebase, not just the changed area.

> "Run tests specific to the changed area." (Targeted tests)

Rationale: Targeted tests exercise the changed behaviour more thoroughly than the global suite.

> "If no targeted tests exist, flag this."

Rationale: Honest reporting. The human should know that the changed area has no dedicated test coverage.

> "Add tests if the change introduces behaviour that existing tests do not cover."

Rationale: New behaviour without tests will have no safety net for future changes.

> "Run the new tests."

Rationale: Writing tests that are never run provides no validation signal. The explicit instruction ensures the agent executes them and confirms they pass.

> "If a new test fails, use the failure output to guide the next implementation change before rerunning."

Rationale: Makes the feedback loop explicit. Without this instruction, the agent tends to treat a failing new test as a problem with the test rather than a signal about the implementation.

> "Do not modify smoke tests or the global test suite unless the task explicitly requires it."

Rationale: Modifying tests to make them pass is a form of scope drift and can mask regressions.

> "Do not run validation commands in parallel when they can share ports, build outputs, caches, or runtime state."

Rationale: Parallel validation with shared state produces flaky, non-deterministic results that waste debugging time.

> "Run smoke tests and the global test suite after each meaningful implementation pass."

Rationale: Frequent validation catches regressions close to the change that introduced them.

> "Do not treat passing smoke tests and the global test suite as proof that the requested behaviour works."

Rationale: Existing tests may not cover the new behaviour. Passing tests only prove nothing was broken, not that the feature works.

> "Treat existing passing tests as evidence of stability."

Rationale: Passing tests confirm the change did not break existing behaviour. They are not proof that new behaviour is correct.

> "Use test results to guide implementation decisions during the Step 5-9 cycle."

Rationale: Frames tests as a steering mechanism for implementation, not just a gate at the end. Tests exist to tell the agent whether it is on track, not just whether it finished correctly.

> "If the change affects state transitions, sync, routing, caching, or reactive UI updates, include validation that follows the full user path."

Rationale: These areas have non-local effects that unit tests cannot catch. The full user path is the only reliable validation.

> "If no automated test exercises the real user path, say so explicitly."

Rationale: Honest reporting. The human needs to know when automated coverage is insufficient.

---

### Validation Requirements: Reporting

> "Report what was tested and what passed."

Rationale: Basic accountability. The human needs to know the validation scope.

> "Report what failed and whether the failure is related to the change."

Rationale: Distinguishing change-caused failures from pre-existing ones prevents unnecessary debugging.

> "Report what was not tested and why."

Rationale: Gaps in testing should be transparent so the human can decide whether additional verification is needed.

> "Do not claim code is tested when it is not."

Rationale: False claims of testing are worse than no testing because they suppress the human's review instinct.

> "Do not ignore failing tests and continue as if the task is complete."

Rationale: Ignoring failures and declaring success is a critical trust violation.

---

### Test Readiness

> "Check whether the project has smoke tests that confirm the app builds and starts."

Rationale: Smoke tests are the minimum safety net. Without them, the baseline comparison model cannot detect build-breaking regressions.

> "Check whether the project has a test suite with at least one passing test."

Rationale: A project with no tests at all has no regression detection. This should be surfaced rather than silently proceeding with zero coverage.

> "Check whether tests exist for the code area the task will touch."

Rationale: Targeted test coverage for the affected area is what gives the implementation feedback loop its signal. Without it, the agent can only rely on smoke tests and manual verification.

> "If any of these are missing, flag the gap to the human before proceeding."

Rationale: The human decides whether to address the gap now or accept the risk. The agent should not make this decision silently.

> "Do not write tests to fill the gap unless the human approves."

Rationale: Writing foundational tests is a scoping decision. It changes the task and should go through the same approval flow as any scope expansion.

> "If the task is specifically about writing tests, skip this check."

Rationale: When the task is to create tests, flagging their absence is redundant.

---

### Writing Tests

> "Use when the plan includes writing new tests." / "Use when Step 6 identifies missing test coverage." / "Use when the task is specifically about creating tests."

Rationale: Defines the three activation conditions. The skill is not needed when only running existing tests.

> "Load the `testing` skill."

Rationale: Defers detailed test-writing guidance to a skill that loads on demand. This keeps the core workflow lean while providing test construction rules when needed.

---

### Manual Verification Requirements

> "Manual verification covers what only a human can verify."

Rationale: Scopes the section to human-only checks, preventing the agent from suggesting automated verifications here.

> "Suggest checks that require human observation: visual behaviour, user experience flows, real-device interaction, external system responses."

Rationale: Concrete examples prevent the agent from suggesting vague "test the feature" checks. Each category represents something the agent cannot observe.

> "Do not suggest checks that can be verified through automated tests or tool output."

Rationale: Manual verification is expensive. Wasting the human's time on checks the agent could automate undermines the workflow's efficiency.

> "State the success signal for each check."

Rationale: The human needs to know what "working" looks like to verify correctly.

> "State the failure signal for each check."

Rationale: The human needs to know what "broken" looks like to catch regressions.

---

### Failure Analysis Mode

> "Enter failure analysis mode when manual verification fails."

Rationale: Manual verification failure means runtime behaviour contradicts the implementation. Speculative fixes without diagnosis make things worse.

> "Enter failure analysis mode when runtime behaviour contradicts the implementation."

Rationale: The contradiction itself is the signal, regardless of how it was discovered.

> "Enter failure analysis mode when test results conflict with observed behaviour."

Rationale: Tests saying one thing and observation saying another indicates a deeper problem that fix attempts will not resolve.

> "Stop implementation and do not make further code changes until failure analysis is complete."

Rationale: Prevents the agent from making speculative fixes while the problem is still undiagnosed. Code changes before diagnosis compound the problem.

> "Before proceeding in failure analysis mode, load the `failure-analysis` skill."

Rationale: Extracts detailed failure analysis procedure to an on-demand skill to keep the core workflow lean. The skill provides the structured reasoning framework.

---

### Logging and Observability

> "When the change requires runtime observability to validate correctness, load the `logging-and-observability` skill."

Rationale: The skill provides runtime visibility so the agent can prove its changes work. Extracting the detailed rules to an on-demand skill reclaims always-on context budget.

---

### Command Approval

> "State what the command does."

Rationale: The human needs to know the effect before approving. Without this, approval is uninformed consent.

> "State why the command needs to run."

Rationale: Context for the approval decision. A command that is unnecessary should not be approved.

---

### GitHub Workflow

> "Link every task to a GitHub issue before implementation."

Rationale: Without an issue, there is no scope boundary, no audit trail, and no way to track what was done.

> "Do not work directly on `main`."

Rationale: Direct work on main bypasses review, breaks the branching model, and risks breaking the shared branch. Enforced deterministically by the pre-commit hook.

> "If the current branch is `main`, stop before implementation and create or switch to an issue-scoped branch."

Rationale: Positive alternative to "do not work on main". Tells the agent what to do, not just what not to do.

> "Do not edit files, run issue validation, or make commits until the issue-scoped branch is active."

Rationale: Any work done on the wrong branch has to be moved later, wasting time and risking errors.

> "Use the branch naming format `type/short-description`."

Rationale: Consistent naming makes branches identifiable by purpose at a glance.

> "Use `feature/` for new functionality." / "Use `fix/` for bug fixes." / "Use `refactor/` for refactors."

Rationale: Concrete branch type prefixes remove ambiguity about which prefix to use.

> "Keep branch work focused on the issue scope."

Rationale: Scope control applied to branch content. A branch should contain one task's changes.

> "Rebase the issue branch onto the target branch before starting implementation."

Rationale: Ensures the starting point matches the current state of the target branch. Code written against a stale base can be silently wrong.

> "Rebase the issue branch onto the target branch before creating a pull request."

Rationale: Ensures CI runs against the current target state, not a stale snapshot. Reduces merge conflicts after PR creation.

> "If new commits have landed on the target branch since the last rebase, rebase again before the next remote GitHub action."

Rationale: Staleness can accumulate during implementation. The rebase must be fresh at the point of the remote action.

> "Before any operation that moves the working tree to a different branch state (rebase, checkout, switch), compare tracked files between the current branch and the target."

Rationale: Catches files committed on the branch that would be carried forward or that conflict with the target state.

> "Before the same operation, check whether gitignored or untracked local files exist at paths the target state tracks."

Rationale: Git overwrites or deletes local files at conflicting paths regardless of gitignore status. Checking first prevents silent data loss.

> "If either check reveals unexpected files or path overlap, stop and report before proceeding."

Rationale: Stopping before the operation gives the human the information needed to decide whether to proceed, clean up, or back up files. Proceeding blindly leads to cleanup operations that risk destroying local files.

> "If the human approves proceeding after a path-overlap report, create a local filesystem backup of the working tree (excluding `.git/`) before running the branch-changing operation."

Rationale: The backup is a safety net against silent file loss during branch operations. No git-native operation preserves gitignored files that are tracked on another branch.

> "Delete the backup only after confirming on the new branch that no expected files were lost."

Rationale: Premature deletion of the backup removes the safety net before the agent has verified the operation was safe.

> "If a rebase produces modify/delete conflicts, stop and discuss with the human before resolving."

Rationale: Modify/delete conflicts signal divergent branch history that may require dropping commits or restructuring rather than mechanical resolution.

> "Treat commit creation, push to remote, and pull request creation as separate GitHub actions."

Rationale: Each remote action has different risk and reversibility. Bundling them removes the human's ability to approve incrementally.

> "Confirm repo-local deterministic policy is active before relying on protected-branch or validation enforcement."

Rationale: If hooks are not installed, the deterministic safety net does not exist. The agent must verify before assuming it is protected.

> "If Git `core.hooksPath` is not `.githooks`, run `./.ai-policy/scripts/install-hooks.sh`."

Rationale: Recovery step. Tells the agent exactly what to do when hooks are not active.

> "Repo-local deterministic policy may block protected-branch Git actions and commit or push without passed validation."

Rationale: Informs the agent that deterministic enforcement exists so it does not interpret a blocked action as a mysterious error.

> "Do not infer approval for one GitHub action from approval for another GitHub action."

Rationale: Prevents chaining. Approval for a commit does not imply approval for a push.

> "Do not push to remote or create a pull request without explicit human confirmation in the current session."

Rationale: Push and PR creation affect shared state, trigger notifications, and are hard to reverse. Each requires explicit, per-session consent.

> "If deterministic policy blocks an action, fix the blocked condition before retrying."

Rationale: Retrying a blocked action without fixing the condition will just fail again. The agent should diagnose and fix (e.g. run validation).

> "If new commits are added after approval, stop and ask again before the next remote GitHub action."

Rationale: New commits change what would be pushed. The human's approval was for the previous state.

> "After running an approved GitHub action, stop and report the result."

Rationale: Prevents the agent from chaining further actions after completing one. The human should see the result and decide next steps.

---

### Handling Parent and Sub-Issues

> "Read the issue comments for clarifications, scope changes, and constraints not in the original body."

Rationale: Comments often contain clarifications, scope changes, or constraints not in the original issue body. Skipping them leads to stale assumptions. This applies to every issue regardless of hierarchy.

> "Treat the parent issue as broader context, not as a work item."

Rationale: Frames the parent as context, not as a task to implement directly. Prevents the agent from treating the parent as the work scope.

> "Do not implement the full parent scope."

Rationale: Implementing the full parent scope would violate scope control. The parent may span multiple tasks across multiple sub-issues.

> "Stop and ask which sub-issue to work on."

Rationale: Prevents the agent from picking a sub-issue arbitrarily. The human should choose which sub-issue to work on.

> "Read the direct parent issue and its comments for context."

Rationale: The parent provides broader context that may inform the sub-issue implementation. Comments on the parent may contain constraints relevant to all sub-issues.

> "Do not read further up the hierarchy."

Rationale: Prevents the agent from spending context window on distant ancestors that provide diminishing context.

> "Implement only the sub-issue scope."

Rationale: Scope control. The sub-issue defines the boundary, not the parent.

> "When completing the sub-issue, check whether it is the last open sub-issue under the parent."

Rationale: Convenience signal so the human knows when a larger piece of work is done.

> "If it is the last open sub-issue, flag this to the human."

Rationale: The human may want to close the parent or review the full body of work.

---

### Boundary Rules: Always Do

> "ALWAYS follow the workflow steps in order."

Rationale: The workflow is a sequence, not a menu. Skipping steps leads to missing inputs or unvalidated output.

> "ALWAYS stop and ask when anything is unclear, risky, or out of scope."

Rationale: The agent should not guess through ambiguity. Guessing introduces errors that are caught late at review rather than early at planning.

> "ALWAYS flag uncertainty, guessed behaviour, and incomplete validation explicitly."

Rationale: Honest reporting. The human cannot compensate for problems they do not know about.

> "ALWAYS stop and ask the human before continuing if two commands in a row do not reduce uncertainty."

Rationale: Non-converging investigation is a signal that the agent is stuck and needs human input rather than more random attempts.

---

### Boundary Rules: Ask First

> "ASK before adding a new dependency."

Rationale: Dependencies are hard to remove, affect build size and security surface, and may conflict with project constraints.

> "ASK before changing architecture or established patterns."

Rationale: Architecture changes affect the entire codebase and require deliberate human decision-making.

> "ASK before changing database schema or sync-related behaviour."

Rationale: Schema changes are among the hardest to reverse and can break data integrity.

> "ASK before changing public interfaces or shared contracts."

Rationale: Public interfaces affect consumers who may not be visible to the agent.

> "ASK before making broad refactors."

Rationale: Broad refactors touch many files, increase review burden, and risk regressions across the codebase.

> "ASK before deleting files or removing significant code paths."

Rationale: Deletion is hard to reverse and may remove functionality that is not obviously referenced.

> "ASK before running `git reset --hard` or any command that discards uncommitted working-tree state."

Rationale: These commands destroy uncommitted changes including gitignored files at conflicting paths. The damage is irreversible and often invisible until the files are needed.

> "ASK before weakening, skipping, or removing tests."

Rationale: Tests are a safety net. Weakening them to make the change pass is a dangerous shortcut.

> "ASK before introducing new conventions or changing existing ones."

Rationale: Conventions affect every future change and should be deliberate human decisions.

> "ASK before introducing a new logging library or pattern."

Rationale: Logging patterns should be consistent across the codebase. A new one fragments the approach.

> "ASK before making assumptions where the task or expected behaviour is unclear."

Rationale: An assumption made silently becomes wrong code. An assumption made explicitly becomes a question.

> "ASK before proceeding when the work conflicts with the current codebase or project constraints."

Rationale: Conflicts should be surfaced, not overridden. The human may have context the agent lacks.

---

### Boundary Rules: Never Do

> "NEVER invent requirements not present in the task or project context."

Rationale: Invented requirements are scope drift by definition. The agent should implement what was asked, not what it thinks should be asked.

> "NEVER silently expand scope or introduce unrelated changes."

Rationale: The most common agent failure mode. Silent expansion undermines the human's ability to review and control the work.

> "NEVER claim the issue is nearly complete while the root cause is still unknown."

Rationale: False progress signals prevent the human from intervening when intervention is needed.

> "NEVER hardcode sensitive values."

Rationale: Hardcoded secrets in code are a security vulnerability that persists in version history.

> "NEVER bypass deterministic policy checks or treat them as optional."

Rationale: Deterministic policy exists because instruction-following alone is unreliable. Bypassing it defeats the safety net.

---

### The Human is Responsible For

> "Define and scope the task before it reaches the AI."

Rationale: The agent works within the scope it is given. If the scope is wrong, the work will be wrong.

> "Decompose larger work into sub-issues and provide a sub-issue rather than the parent as the starting input."

Rationale: The agent should not decompose work. Decomposition is a design decision that belongs to the human.

> "Provide a well-formed GitHub issue as the starting input."

Rationale: The workflow starts from an issue. A missing or poorly formed issue means the agent has no clear target.

> "Ensure the right project context is available."

Rationale: The agent reads what is available. If project-spec.md is missing or stale, the agent's understanding will be wrong.

> "Review and approve the plan before coding starts."

Rationale: The plan checkpoint exists to catch wrong approaches early. If the human does not review, the checkpoint is wasted.

> "Monitor for scope drift during implementation."

Rationale: The agent has rules against scope drift, but the human is the ultimate check. Agents can rationalise expansion.

> "Perform manual verification where automated tests are not sufficient."

Rationale: Some behaviour can only be verified by a human observing the running application.

> "Report issues found during review or testing."

Rationale: The agent cannot see what the human sees during manual verification. Reported issues drive the fix-and-revalidate loop.

> "Merge pull requests."

Rationale: Merging is a human decision that affects the shared branch. The agent should not merge its own work.

> "Communicate the intent of issues clearly when delegating issue creation."

Rationale: When the agent creates follow-up issues on behalf of the human, the quality depends on the human communicating what they want captured.

> "Decide when the work is complete."

Rationale: Completion is a human judgment. The agent should not declare its own work done.
