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

> "Read the issue and its comments."

Rationale: Comments often contain clarifications, scope changes, or constraints not in the original issue body. Skipping them leads to stale assumptions.

> "Check parent and sub-issue structure."

Rationale: Prevents the agent from accidentally implementing an entire parent issue when only a sub-issue was intended.

> "Check branch state."

Rationale: The agent must not work on a protected branch. Checking early prevents wasted work that has to be moved later.

> "Rebase onto the target branch."

Rationale: Working on a stale branch means writing code against an outdated state. Files may have moved, APIs may have changed, or new conflicts may have accumulated.

> "Run baseline validation."

Rationale: The rule "if a previously passing test fails after the change, treat the change as wrong" is unenforceable without a known-good baseline. The baseline distinguishes regressions from pre-existing failures.

> "Confirm the task is a bounded change."

Rationale: Unbounded tasks lead to scope drift. Confirming boundaries early forces the agent to flag multi-objective issues or overly broad tasks before starting.

> "Complete this step before analysing implementation details."

Rationale: Prevents the agent from jumping into code analysis before confirming the task inputs are correct. Premature analysis wastes context on the wrong problem.

---

### Workflow Step 2: Review project context

> "Read `project-spec.md` and relevant files."

Rationale: The project spec provides architectural patterns, structure, and conventions. Reading it before planning prevents the agent from proposing changes that conflict with established patterns.

> "Review the code areas the task is likely to touch."

Rationale: The agent must verify that the code matches what the issue assumes. Issues are written against the author's mental model, which may be stale.

> "Extract the intended outcome from the issue before using implementation suggestions."

Rationale: Separates the goal (what should change) from the means (how to change it). The goal is authoritative; the implementation suggestions need verification against the current codebase.

---

### Workflow Step 3: Produce a code-aware plan

> "Write the plan."

Rationale: The plan exists as a checkpoint artifact that gives the human a concrete, reviewable description of what the agent intends to do before any code changes happen.

---

### Workflow Step 4: Checkpoint - human reviews the plan

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

### Workflow Step 8: Checkpoint - human reviews validation and manual verification

Rationale: Gate before the agent proceeds to fixes. The human may have observations the agent cannot detect.

---

### Workflow Step 9: Fix and revalidate

> "Fix reported issues."

Rationale: Directs the agent to address what the human identified during the checkpoint. Without this explicit instruction, the agent might only partially address feedback or prioritise easy fixes.

> "Rerun relevant validation checks after each fix."

Rationale: A fix can introduce new regressions. Re-validating after each fix prevents error compounding.

> "Repeat until no issues remain."

Rationale: Sets an explicit termination condition. Without it the agent may stop after one pass even when multiple issues were reported.

> "Enter Failure Analysis Mode if a fix fails." / "Enter Failure Analysis Mode if manual verification fails."

Rationale: Prevents the agent from cycling through speculative fixes. Manual verification failure means runtime contradicts the implementation. Forces structured reasoning before more code changes.

---

### Workflow Step 10: Summarise and prepare handoff

> "Report what changed."

Rationale: Gives the human a clear picture of the implementation for review.

> "Report what was tested."

Rationale: Establishes what the agent has validated, so the human knows what is covered.

> "Report what was not tested."

Rationale: Honest reporting prevents the human from assuming full coverage when there are gaps.

> "Report remaining risks and follow-up work."

Rationale: The agent may have discovered problems outside the current scope. These should be surfaced, not silently dropped.

> "Check parent and sub-issue closure status."

Rationale: Lets the human know whether completing this sub-issue closes the parent.

> "State which GitHub action would be next if the human wants to publish the work."

Rationale: Prepares the handoff. The agent proposes; the human decides.

---

### Workflow Step 11: Checkpoint - human approves the next GitHub action

> "Stop after the summary until the human explicitly approves the next GitHub action in the current session."

Rationale: Prevents the agent from pushing code or creating PRs based on momentum. Each remote action requires explicit consent.

---

### Workflow Step 12: Run the approved GitHub action and stop

> "Run only the single GitHub action the human explicitly approved."

Rationale: Prevents chaining (e.g. human approves a push, agent also creates a PR). Each action is a separate approval.

---

### Planning Requirements

> "State the branch the work will be implemented on."

Rationale: Makes the branch explicit in the plan so the human can verify it before coding starts.

> "State the goal of the change in one or two sentences."

Rationale: Forces the agent to articulate the goal concisely. A plan without a clear goal cannot be reviewed.

> "State the user-visible behaviour that must change."

Rationale: Keeps the plan grounded in outcomes, not just code changes. The human can verify whether the right thing is being changed.

> "State the files and code areas the change will touch."

Rationale: Gives the human a scope preview and forces the agent to verify these files exist and are the right targets.

> "State the proposed implementation approach."

Rationale: The reviewable core of the plan. The human can catch wrong approaches before they become wrong code.

> "State any assumptions the plan depends on."

Rationale: Makes hidden assumptions explicit so the human can validate or challenge them.

> "Separate issue assumptions from codebase-confirmed assumptions."

Rationale: Forces the agent to be explicit about what it knows versus what it is guessing. The human can spot wrong assumptions before they become wrong code.

> "State how each critical assumption will be verified."

Rationale: An assumption without a verification plan is a guess that will not be caught until it fails in production.

> "State any remaining uncertainties or ambiguities."

Rationale: Honest uncertainty reporting lets the human resolve ambiguities before coding starts, when it is cheapest.

> "State the risks and edge cases."

Rationale: Forces proactive risk identification rather than discovering edge cases during implementation or review.

> "Mark the change as higher-risk if it affects routing, persistence, sync, caching, reactive subscriptions, or state transitions."

Rationale: These areas have non-local effects. A bug can appear correct locally but break a different screen or surface only after a delay.

> "Include at least one runtime validation step for higher-risk changes."

Rationale: Higher-risk areas cannot be validated by unit tests alone. Runtime validation catches problems that only manifest in the full execution context.

> "State the validation approach."

Rationale: Commits the plan to a specific validation strategy that the human can review.

> "State any logging or observability changes needed."

Rationale: Logging decisions should be deliberate and planned, not afterthoughts during implementation.

> "Treat the issue goal as authoritative."

Rationale: The goal (what should change) comes from the human who filed the issue. The agent should not second-guess the goal itself.

> "Treat issue-suggested implementation details as provisional until the current codebase confirms them."

Rationale: Issues are written against the author's mental model, which may be stale or wrong. The agent must verify before trusting.

> "Do not assume the files, data flow, or control points named in the issue are the real execution path."

Rationale: The issue may reference files that no longer exist or logic that has moved.

> "If the issue and the current codebase disagree, prioritise the codebase and flag the mismatch to the human."

Rationale: First principle: the codebase provides implementation truth. The agent should not silently follow stale issue instructions.

> "If the issue suggests a structure that the current codebase does not follow, plan against the real structure and flag the mismatch to the human."

Rationale: Planning against a structure that does not exist produces code that does not work.

> "Keep the plan concise."

Rationale: Long plans waste context tokens and are harder for the human to review. Brevity forces precision.

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

> "Do only the work required to complete the task."

Rationale: The fundamental scope rule. Everything else in this section is a specific application of this principle.

> "Do not treat 'while I am here' changes as free."

Rationale: Agents optimise for perceived completeness, leading to unrequested refactors and cosmetic changes that increase review burden and risk.

> "Separate fixes, refactors, and feature work unless the task clearly requires them together."

Rationale: Mixing change types in one task makes review harder and makes it impossible to revert one type without reverting the others.

> "If a larger problem is discovered, flag it as follow-up work instead of silently broadening the implementation."

Rationale: Silently broadening scope is the most common agent failure mode. Flagging preserves scope while ensuring the problem is not lost.

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

> "Do not modify smoke tests or the global test suite unless the task explicitly requires it."

Rationale: Modifying tests to make them pass is a form of scope drift and can mask regressions.

> "Do not run validation commands in parallel when they can share ports, build outputs, caches, or runtime state."

Rationale: Parallel validation with shared state produces flaky, non-deterministic results that waste debugging time.

> "Run smoke tests and the global test suite after each meaningful implementation pass."

Rationale: Frequent validation catches regressions close to the change that introduced them.

> "Do not treat passing smoke tests and the global test suite as proof that the requested behaviour works."

Rationale: Existing tests may not cover the new behaviour. Passing tests only prove nothing was broken, not that the feature works.

> "Treat existing passing tests as evidence of stability."

Rationale: Passing tests confirm the change did not break existing behaviour.

> "Do not treat existing passing tests as proof of correctness for new behaviour."

Rationale: New behaviour needs its own tests. Existing tests were not written to validate it.

> "If the change affects state transitions, sync, routing, caching, or reactive UI updates, include validation that follows the full user path."

Rationale: These areas have non-local effects that unit tests cannot catch. The full user path is the only reliable validation.

> "If no automated test exercises the real user path, say so explicitly."

Rationale: Honest reporting. The human needs to know when automated coverage is insufficient.

> "If manual verification fails, stop implementation mode and enter Failure Analysis Mode before making more code changes."

Rationale: Prevents speculative fix cycles. Forces structured diagnosis first.

---

### Validation Requirements: Reporting

> "Report what was tested and what passed."

Rationale: Basic accountability. The human needs to know the validation scope.

> "Report what failed and whether the failure is related to the change."

Rationale: Distinguishing change-caused failures from pre-existing ones prevents unnecessary debugging.

> "Report what was not tested and why."

Rationale: Gaps in testing should be transparent so the human can decide whether additional verification is needed.

> "Report failures honestly, including failures unrelated to the change."

Rationale: Hiding failures undermines trust and prevents the human from tracking codebase health.

> "Do not claim code is tested when it is not."

Rationale: False claims of testing are worse than no testing because they suppress the human's review instinct.

> "Do not ignore failing tests and continue as if the task is complete."

Rationale: Ignoring failures and declaring success is a critical trust violation.

---

### Manual Verification Requirements

> "Suggest specific manual checks based on the change."

Rationale: Generic "test the feature" is not actionable. Specific checks tell the human exactly what to verify.

> "State the success signal for each check."

Rationale: The human needs to know what "working" looks like to verify correctly.

> "State the failure signal for each check."

Rationale: The human needs to know what "broken" looks like to catch regressions.

---

### Failure Analysis Mode: Entry conditions

> "Enter failure analysis mode when manual verification fails."

Rationale: Manual verification failure means runtime behaviour contradicts the implementation. Speculative fixes without diagnosis make things worse.

> "Enter failure analysis mode when runtime behaviour contradicts the implementation."

Rationale: The contradiction itself is the signal, regardless of how it was discovered.

> "Enter failure analysis mode when test results conflict with observed behaviour."

Rationale: Tests saying one thing and observation saying another indicates a deeper problem that fix attempts will not resolve.

---

### Failure Analysis Mode: Procedure

> "Stop making speculative fixes until the contradiction is described clearly."

Rationale: The default agent behaviour is to immediately attempt fixes, making the problem worse. Stopping forces reasoning first.

> "State the observed behaviour in user terms." / "State the expected behaviour in user terms."

Rationale: Framing in user terms prevents the agent from describing the problem in code terms that obscure the actual failure.

> "Restate the contradiction in one short block before any reasoning."

Rationale: Forces the agent to articulate the problem clearly before attempting to solve it.

> "Use this format: observed behaviour, expected behaviour, strongest conflicting evidence, and what remains unknown."

Rationale: Structured format prevents the agent from skipping steps or burying contradictions in prose.

> "List the assumptions the implementation relied on." / "Mark each assumption as verified, unverified, or disproved."

Rationale: Makes hidden assumptions explicit and forces the agent to check which ones still hold.

> "List plausible failure causes across issue interpretation, code path selection, persistence, sync, caching, routing, UI binding, environment, test coverage, and observability."

Rationale: The checklist prevents tunnel vision. Without it, agents fixate on the first hypothesis and ignore alternatives.

> "Identify the cheapest next observation that can eliminate one or more hypotheses."

Rationale: Directs the agent toward the single observation that would eliminate the most hypotheses rather than cycling through random fixes.

> "If multiple hypotheses exist, prefer the next observation that distinguishes between wrong code path, wrong write, later overwrite, sync overwrite, and stale runtime."

Rationale: These are the most common competing explanations for state-related bugs. Distinguishing between them early saves debugging time.

> "Name the single leading hypothesis before proposing the next step."

Rationale: Forces commitment to a hypothesis, making the reasoning testable and the next step purposeful.

> "State the evidence that currently supports the leading hypothesis."

Rationale: Evidence-backed hypotheses are more likely correct than guesses. If the evidence is thin, that itself is useful information.

> "If repeated fixes under different hypotheses are not converging, state this clearly."

Rationale: Non-convergence is a signal that the approach is fundamentally wrong, not that the agent needs to try harder.

> "If investigation reveals that the plan was based on incorrect assumptions about the codebase, state this clearly."

Rationale: Admitting the plan was wrong is necessary to course-correct. Without this rule, agents try to preserve wrong plans.

> "Report what the plan assumed." / "Report what the codebase actually does." / "Report what a revised approach would need to account for."

Rationale: Structured disclosure of the gap between plan and reality, enabling the human to approve a revised approach.

> "If the contradiction involves a write, state transition, sync boundary, or reactive screen, prefer temporary diagnostics or direct observation over a retry request."

Rationale: Agents frequently ask the human to "try again" as a substitute for understanding what went wrong. Diagnostics produce evidence; retries often do not.

> "Gather evidence before proposing another fix."

Rationale: Prevents fix-without-diagnosis cycles.

> "Test at least one concrete hypothesis before asking the human to retry the flow, refresh the app, clear cache, restart the dev server, or repeat manual verification."

Rationale: Retry requests shift debugging effort to the human and often do not resolve the issue.

> "Prioritise code path, persistence, sync, routing, and UI binding explanations over environment or caching unless evidence shows otherwise."

Rationale: Environment and caching are convenient scapegoats but rarely the actual cause. Code-level explanations are more often correct.

> "Do not signal a flawed approach based on difficulty alone."

Rationale: Difficulty is not evidence of a wrong approach. Premature pivoting wastes the work already done.

> "Signal a flawed approach only when evidence shows the assumptions were wrong."

Rationale: The trigger for changing approaches should be evidence, not frustration.

---

### Logging and Observability: When to add logging

> "Decide whether additional logging or observability is needed when the change introduces user-facing flows, data writes, sync operations, state transitions, silently failing error handling paths, or integration points between layers."

Rationale: These are the areas where problems are hardest to diagnose after the fact. Logging here provides the most diagnostic value per line.

---

### Logging and Observability: Adding logging

> "Use the project's existing logging approach."

Rationale: Consistency. Introducing a new logging pattern is scope drift.

> "If no logging approach exists, flag this in the plan."

Rationale: Negative rules need a positive alternative. Flagging it lets the human decide rather than leaving the agent stuck.

> "Log the action, relevant identifiers, and outcome."

Rationale: The minimum useful log entry: action plus identifiers plus outcome is enough to trace a problem.

> "Include enough context to trace a problem without a debugger."

Rationale: If the log requires a debugger to interpret, it has not saved any time.

> "Do not add logging for trivial operations."

Rationale: Verbose logging obscures the meaningful entries and wastes output.

> "Do not add logging that would expose sensitive user data."

Rationale: Security boundary. Logs can be leaked through terminals, commits, or monitoring systems.

> "Do not log full data payloads unless explicitly needed."

Rationale: Full payloads bloat logs and may contain sensitive data. Log identifiers and outcomes instead.

> "If a change affects writes, sync behaviour, state transitions, or reactive screens, decide whether temporary diagnostic logging is needed to verify the runtime path."

Rationale: During development, the agent may need to prove which code path executed before the human can verify the feature works.

> "Prefer logs or probes that confirm which code path executed." / "Prefer logs or probes that confirm which identifiers were used." / "Prefer logs or probes that confirm which state transition occurred."

Rationale: These three pieces of information resolve the most common debugging questions for state-related bugs.

> "If observability is too weak to distinguish between competing hypotheses, flag this before continuing."

Rationale: Continuing without sufficient observability means the next failure will be equally hard to diagnose.

> "Remove temporary diagnostics before completion unless the human approves keeping them."

Rationale: Prevents debug logging from accumulating in the codebase across tasks.

> "If a higher-risk change fails manual verification before the runtime path is proven, decide whether temporary diagnostics or another direct observation method is needed before asking the human to retry."

Rationale: Asking the human to retry without diagnostics produces no new information.

---

### Logging and Observability: Investigation

> "Prefer automated diagnostics over asking the human to observe and report."

Rationale: Automated diagnostics are reproducible, structured, and do not burden the human with observation tasks the agent could handle.

> "Write diagnostics that capture structured, non-sensitive output."

Rationale: Structured output is parseable by the agent. Non-sensitive output is safe to capture.

> "Capture event types, state changes, control flow decisions, and timestamps when relevant."

Rationale: These are the data points that resolve most debugging questions.

> "Run the diagnostic." / "Read the results." / "Use the results to drive the next step."

Rationale: Explicit sequencing prevents the agent from writing a diagnostic and then ignoring its output.

> "If a diagnostic cannot avoid capturing sensitive data, do not write it."

Rationale: Security boundary. No diagnostic is worth a data leak.

> "Describe what to look for." / "Let the human observe it directly."

Rationale: The fallback when automated diagnostics cannot be made safe. The human observes; the agent does not capture sensitive data.

> "Only ask the human to provide logs or reproduce behaviour when automated observation is not possible."

Rationale: Automated observation is preferred because it is cheaper and more reliable. Human observation is the fallback.

> "If only the human can trigger the condition, ask the human to trigger it and provide the raw output."

Rationale: Some conditions require human interaction. The agent should ask for raw output, not interpreted results.

> "Do not ask the human to interpret the results."

Rationale: Interpretation is the agent's job. Asking the human to interpret shifts cognitive burden without adding value.

> "Do not write diagnostics that output sensitive data, including tokens, credentials, PII, full payloads, or anything that could identify a real user."

Rationale: Comprehensive security boundary. The list is explicit to prevent the agent from rationalising exceptions.

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

> "Before rebasing, compare tracked files between the branch and target and check whether gitignored or untracked local files exist at paths the target state tracks."

Rationale: Catches two classes of problem before the rebase starts: junk files committed on the branch that would be carried forward, and local gitignored files at paths the target tracks that git would overwrite or delete.

> "If either check reveals unexpected files or path overlap, stop and report before proceeding."

Rationale: Stopping before the rebase gives the human the information needed to decide whether to proceed, clean up the branch, or back up local files. Proceeding blindly leads to cleanup operations that risk destroying local files.

> "If a rebase produces modify/delete conflicts, stop and discuss with the human before resolving."

Rationale: Modify/delete conflicts signal divergent branch history that may require dropping commits or restructuring rather than mechanical resolution. Mechanical resolution without understanding the divergence can carry forward files that should have been dropped.

> "If the task changes significantly during implementation, update the issue or flag the mismatch to the human."

Rationale: The issue is the scope contract. If implementation diverges, the issue must be updated or the human must be informed.

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

> "Do not push to remote without explicit human confirmation in the current session."

Rationale: Push affects shared state and is hard to reverse. Requires explicit, per-session consent.

> "Do not create a pull request without explicit human confirmation in the current session."

Rationale: PR creation affects shared state and triggers notifications. Requires explicit consent.

> "If deterministic policy blocks an action, fix the blocked condition before retrying."

Rationale: Retrying a blocked action without fixing the condition will just fail again. The agent should diagnose and fix (e.g. run validation).

> "If new commits are added after approval, stop and ask again before the next remote GitHub action."

Rationale: New commits change what would be pushed. The human's approval was for the previous state.

> "After running an approved GitHub action, stop and report the result."

Rationale: Prevents the agent from chaining further actions after completing one. The human should see the result and decide next steps.

---

### Handling Parent and Sub-Issues

> "Treat a parent issue as broader context that may list sub-issues."

Rationale: Frames the parent as context, not as a task to implement directly.

> "Treat a sub-issue as a single bounded work item."

Rationale: Sub-issues are the unit of work. Each one should be implementable in a single task.

> "If the provided issue is a parent issue with sub-issues, do not implement the full parent scope."

Rationale: Implementing the full parent scope would violate scope control. The parent may span multiple tasks.

> "If the provided issue is a parent issue with sub-issues, stop and ask which sub-issue to work on."

Rationale: Prevents the agent from picking a sub-issue arbitrarily. The human should choose.

> "If the provided issue is a sub-issue, read the parent issue and its comments for context."

Rationale: The parent provides broader context that may inform the sub-issue implementation.

> "If the provided issue is a sub-issue, do not read further up the hierarchy."

Rationale: Prevents the agent from spending context window on distant ancestors that provide diminishing context.

> "If the provided issue is a sub-issue, implement only the sub-issue scope."

Rationale: Scope control. The sub-issue defines the boundary.

> "If the provided issue has no sub-issues, treat it as a standalone work item."

Rationale: Handles the common case where issues are flat, not hierarchical.

> "When completing a sub-issue, check whether it is the last open sub-issue under the parent."

Rationale: Convenience signal so the human knows when a larger piece of work is done.

> "If the completed sub-issue is the last open sub-issue under the parent, flag this to the human."

Rationale: The human may want to close the parent or review the full body of work.

---

### Boundary Rules: Always Do

> "Follow the workflow steps in order."

Rationale: The workflow is a sequence, not a menu. Skipping steps leads to missing inputs or unvalidated output.

> "Stop and ask when anything is unclear, risky, or out of scope."

Rationale: The agent should not guess through ambiguity. Guessing introduces errors that are caught late at review rather than early at planning.

> "Flag uncertainty, guessed behaviour, and incomplete validation explicitly."

Rationale: Honest reporting. The human cannot compensate for problems they do not know about.

> "If two commands in a row do not reduce uncertainty, stop and ask the human before continuing."

Rationale: Non-converging investigation is a signal that the agent is stuck and needs human input rather than more random attempts.

---

### Boundary Rules: Ask First

> "Adding a new dependency."

Rationale: Dependencies are hard to remove, affect build size and security surface, and may conflict with project constraints.

> "Changing architecture or established patterns."

Rationale: Architecture changes affect the entire codebase and require deliberate human decision-making.

> "Changing database schema or sync-related behaviour."

Rationale: Schema changes are among the hardest to reverse and can break data integrity.

> "Changing public interfaces or shared contracts."

Rationale: Public interfaces affect consumers who may not be visible to the agent.

> "Making broad refactors."

Rationale: Broad refactors touch many files, increase review burden, and risk regressions across the codebase.

> "Deleting files or removing significant code paths."

Rationale: Deletion is hard to reverse and may remove functionality that is not obviously referenced.

> "Running `git reset --hard` or any command that discards uncommitted working-tree state."

Rationale: These commands destroy uncommitted changes including gitignored files at conflicting paths. The damage is irreversible and often invisible until the files are needed.

> "Weakening, skipping, or removing tests."

Rationale: Tests are a safety net. Weakening them to make the change pass is a dangerous shortcut.

> "Introducing new conventions or changing existing ones."

Rationale: Conventions affect every future change and should be deliberate human decisions.

> "Introducing a new logging library or pattern."

Rationale: Logging patterns should be consistent across the codebase. A new one fragments the approach.

> "Making assumptions where the task or expected behaviour is unclear."

Rationale: An assumption made silently becomes wrong code. An assumption made explicitly becomes a question.

> "Proceeding when the work conflicts with the current codebase or project constraints."

Rationale: Conflicts should be surfaced, not overridden. The human may have context the agent lacks.

---

### Boundary Rules: Never Do

> "Invent requirements not present in the task or project context."

Rationale: Invented requirements are scope drift by definition. The agent should implement what was asked, not what it thinks should be asked.

> "Silently expand scope or introduce unrelated changes."

Rationale: The most common agent failure mode. Silent expansion undermines the human's ability to review and control the work.

> "Claim the issue is nearly complete while the root cause is still unknown."

Rationale: False progress signals prevent the human from intervening when intervention is needed.

> "Hardcode sensitive values."

Rationale: Hardcoded secrets in code are a security vulnerability that persists in version history.

> "Bypass deterministic policy checks or treat them as optional."

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

> "Decide when the work is complete."

Rationale: Completion is a human judgment. The agent should not declare its own work done.
