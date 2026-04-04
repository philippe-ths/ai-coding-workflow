# AI Workflow Design Decisions

This document captures the structural principles and design rationale behind `ai-workflow.md`.
It is for the human maintainer.
When editing the workflow file, use these principles to guide changes.

## Audience

The file is written for an AI coding agent.
The human does not need to read it during a task.
The human reads it when maintaining or updating the file.

The "Human is Responsible For" section is also written for the AI agent.
It tells the agent what it cannot do and must leave to the human.

## File Structure

The file is organised into six distinct section types.
Each section type has a single responsibility.

**Preamble.**
Context only.
What this file is, who it is for.
Contains no rules or principles.

**First Principles.**
The governing truths.
Keep this section as short as possible.
Every line must earn its place by being genuinely foundational.
The workflow must be model-agnostic and repo-agnostic.

**Workflow.**
The ordered sequence of steps for every task.
Each step should describe what happens and when, not how to do it in detail.
Detailed rules belong in reference sections.
The workflow points to reference sections rather than inlining their content.
Human checkpoints are explicit numbered steps.

**Reference sections.**
The detailed "how" for specific topics: planning, implementation, scope, validation, failure analysis, logging, GitHub workflow, sub-issue handling.
These do the heavy lifting.
Each reference section owns its topic.
Rules about that topic should live here, not scattered across the workflow or boundary sections.

**Boundary rules.**
Global, context-free rules that apply regardless of which step or topic is active.
Rules that don't fit into Reference sections.
Three tiers: Always Do, Ask First, Never Do.

**Human responsibilities.**
What the AI cannot do.
This exists so the agent knows where to stop and hand off.

## Maintenance Rules

**One canonical location per rule.**
Every rule should exist in exactly one place.
If the same rule appears in two sections, decide which section owns it and remove the other.
Duplication causes drift over time and wastes context tokens.
When a rule has both an advisory form and an enforcement form, keep the advisory form once in `ai-workflow.md` and keep the enforcement form in repo-local deterministic policy.

**One sentence per line.**
Every line should contain exactly one sentence.

**No em-dashes.**

**Writing style.**
Every line should be a direct instruction or a direct statement of fact.
Use imperative mood: "Do X", "Do not do X", "Flag this to the human."
Do not use passive voice: "The plan should be reviewed" is weaker than "Wait for the human to review the plan."
When there is a conditional, put the condition first: "If X, do Y."
Do not hedge: avoid "consider", "you might want to", "it is generally a good idea to."
The file instructs. It does not teach, persuade, or justify.
Do not include rationale for bright-line mechanical rules where the instruction is unambiguous on its own.
Include inline rationale for a rule only when all three criteria are met: the rule requires a judgment call, an agent could comply with the literal wording while violating the intent, and understanding the why would materially change how the agent applies the rule in ambiguous cases.
Use the format: rule sentence on its own line, then "(Why: rationale.)" on the next line or in a parenthetical on the same line.
Every rationale line consumes tokens that compete with the actual task, so each one must earn its place.


**Negative rules need a positive alternative.**
A rule that only says "Do not do X" leaves the agent guessing what to do instead.
Where possible, pair it with the correct action: "Do not add logging for trivial operations" is fine because the alternative is obvious (do nothing). "Do not use console.log" is incomplete without "Use the project logger instead."

**Concrete over abstract.**
Prefer concrete actions over abstract goals.
"Run the full test suite" over "Ensure adequate test coverage."
"Flag the mismatch to the human" over "Communicate discrepancies appropriately."
Abstract instructions give the agent room to interpret, which means room to get it wrong.

**Keep lines short.**
If a line needs a subordinate clause to make sense, it is probably two rules and should be split.
Long lines are harder for the model to attend to and easier to partially skip.

**Emphasis formatting.**
Do not use bold, caps, or exclamation marks as a general priority signal across the file.
Position in the file and placement in First Principles remain the primary priority signals.
Exception: apply CAPS to the opening action verb in boundary rule bullets only (ALWAYS, ASK, NEVER).
This targets generation-time salience for unconditional rules, not abstract priority.
Do not extend caps emphasis to reference section rules or workflow steps.
If emphasis is used broadly, it loses its salience effect and adds noise tokens.

**Context budget.**
Every line in the file consumes context window tokens that compete with the actual task.
Research suggests frontier models reliably follow roughly 150-200 instructions, with degradation uniform across all rules as the count increases.
The agent tool's own system prompt already consumes some of this budget before the workflow file loads.
This means every low-value line added dilutes the compliance probability of every high-value line.
Before adding a rule, ask: could the agent figure this out by reading the codebase?
If yes, do not add it.
If a boundary is bright-line and machine-checkable, prefer deterministic repo-local enforcement over repeated workflow wording.
Prefer fewer, higher-quality rules over comprehensive coverage.

**Deterministic policy placement.**
Bright-line machine-checkable boundaries should move into deterministic repo-local policy when practical.
Keep the behavioral instruction in `ai-workflow.md` if the AI needs it to plan and sequence work correctly before enforcement.
If advisory guidance depends on deterministic policy being active, state the activation check and recovery step once in the owning reference section.
Do not restate the same mechanically enforced boundary across multiple workflow sections.

**Workflow steps should be lean.**
A workflow step should contain sequenced actions and pointers to reference sections.
It should not contain detailed rules, principles, or human responsibility statements.
If a line in a workflow step reads like a rule rather than a sequenced action, it probably belongs in a reference section or boundary section.

**Human responsibilities do not belong in workflow steps.**
Lines describing what the human does (e.g. "Human reviews the results") should not appear inline in workflow steps.
Human checkpoints are expressed as explicit numbered steps (e.g. "Checkpoint: human reviews the plan.").
Detailed human responsibilities live in the Human Responsibilities section.

**Boundary rules are context-free. Reference section rules are context-dependent.**
A rule belongs in the boundary section if it applies regardless of which step or topic is active.
A rule belongs in a reference section if it only makes sense within that section's topic.
If a rule appears in both places, ask: does this rule need the surrounding context to be actionable?
If it does, the reference section is the canonical location.
If it does not, the boundary section is the canonical location.
Do not keep it in both.

**Boundary rule clustering.**
Over time, boundary rules tend to accumulate.
When 4-5 or more boundary rules cluster around the same topic, that is a signal the topic deserves its own reference section.
Extract the cluster into a new reference section and remove the individual rules from the boundary section.
The real test is whether the rules share a context: if you would naturally read them together and they reference the same concepts, they are a cluster.
This keeps the boundary sections lean and genuinely global.

**Keep First Principles minimal.**
Only add a line to First Principles if it is genuinely foundational and not adequately expressed by the workflow structure or any reference/boundary section.
If a principle can live in a reference section instead, put it there.

**Chronological session logs are an optional maintenance output.**
When maintaining the workflow, the human may request a chronological session log.
The log should list each material observation, decision, proposed wording change, accepted change, rejected change, and file edit in order.
The log should separate applied changes from ideas that were discussed but not adopted.
The log should omit filler conversation and low-signal tool noise.

## File Splitting

The workflow file can be split into a core file and topic-specific files loaded on demand.
The core file contains the workflow steps, boundary rules, human responsibilities, and first principles.
Topic-specific files contain reference section content that is only relevant during a specific phase or condition.

A section qualifies for extraction when all of the following are true:
1. It activates under a specific, identifiable condition or phase.
2. It is self-contained and has no dependencies on other sections during its active phase.
3. It is not needed in context during the majority of sessions or phases.

Loading is agent-driven: the core workflow instructs the agent to read the file at the right moment.
This approach works across all agent tools because file reading is a universal capability.
Tool-native mechanisms (such as Claude Code path-scoped rules or @imports) can supplement agent-driven loading but should not replace it as the primary mechanism.

Keep boundary rules (Always Do, Ask First, Never Do) in the core file.
These are context-free and must be in context at all times.

Extracted files live in a `workflow/` directory at the repository root.
Each file covers one topic and follows the same formatting rules as the core workflow.

## Reusable Prompt

Use this prompt when requesting a chronological session log for workflow maintenance.

```text
Produce a chronological log of this chat session for maintenance of the file ai-workflow.md.
List the following: 
- [Tooling or environment, e.g. VS Code Copilot, ChatGPT app, CLI agent.]
- [Model if known, e.g. GPT-5.4.]
- [Repo or project.]
List each material observation, decision, proposed wording change, accepted change, rejected change, and file edit in order.
List any rules you clearly ignored in ai-workflow.md
Separate applied changes from ideas that were discussed but not adopted.
Omit filler chat and low-signal tool output.
Do not use tables.
```

## Cross-Contamination Categories

When reviewing the file for structural problems, classify each line as one of:

- **OK.** Line is in the right place.
- **Cross-contaminated.** Content type does not match the section's purpose (e.g. a rule in the preamble, a principle in a workflow step).
- **Redundant.** The same rule is stated in multiple places.
- **Misplaced.** The line belongs in a different specific section (e.g. a human responsibility in a workflow step).
- **Candidate to move.** The line could be offloaded to a reference section with a pointer left behind.


## Line-by-Line Rationale for ai-workflow.md

Every line from `ai-workflow.md` is listed below with its rationale and source.

---

### Preamble

> "This file defines the workflow for AI-assisted coding on this project."

Rationale: Establishes the file's purpose so both human maintainers and AI agents know what they are reading.
Source: File structure principle (Preamble section provides context only).

> "It is written for the AI coding agent."

Rationale: Sets the audience explicitly. The human does not need to read this during a task; it exists to instruct the agent.
Source: Audience design decision.

> "The human reviews and approves at defined checkpoints."

Rationale: Establishes the human-in-the-loop model upfront. The agent works; the human approves at defined gates.
Source: Core workflow architecture.

---

### First Principles

> "The codebase provides implementation truth."

Rationale: Prevents the agent from trusting documentation, issue descriptions, or its own prior assumptions over what the code actually does. When ambiguous, the agent should read the code, not re-read the issue or guess from file names.
Source: Observed failure pattern where agents trust stale mental models over current code.

> "Runtime behaviour is the final source of truth."

Rationale: If the code says one thing and runtime says another, runtime wins. Prevents the agent from declaring a task complete because the code looks correct while the feature is actually broken.
Source: Observed failure pattern where agents stop at "the code looks right" without verifying behaviour.

---

### Workflow Step 1: Confirm the task and inputs

> "Confirm the GitHub issue number."

Rationale: Links every task to a trackable artifact. Without an issue number, there is no scope boundary and no audit trail.
Source: GitHub Workflow reference section.

> "Read the issue and its comments."

Rationale: Comments often contain clarifications, scope changes, or constraints not in the original issue body. Skipping them leads to stale assumptions.
Source: Planning Requirements (issue goal is authoritative; details need verification).

> "Check parent and sub-issue structure."

Rationale: Prevents the agent from accidentally implementing an entire parent issue when only a sub-issue was intended.
Source: Handling Parent and Sub-Issues reference section.

> "Check branch state."

Rationale: The agent must not work on a protected branch. Checking early prevents wasted work that has to be moved later.
Source: GitHub Workflow reference section.

> "Rebase onto the target branch."

Rationale: Working on a stale branch means writing code against an outdated state. Files may have moved, APIs may have changed, or new conflicts may have accumulated.
Source: Baseline Validation and Rebasing design decision.

> "Run baseline validation."

Rationale: The rule "if a previously passing test fails after the change, treat the change as wrong" is unenforceable without a known-good baseline. The baseline distinguishes regressions from pre-existing failures.
Source: Baseline Validation and Rebasing design decision.

> "Confirm the task is a bounded change."

Rationale: Unbounded tasks lead to scope drift. Confirming boundaries early forces the agent to flag multi-objective issues or overly broad tasks before starting.
Source: Scope Control reference section.

> "Complete this step before analysing implementation details."

Rationale: Prevents the agent from jumping into code analysis before confirming the task inputs are correct. Premature analysis wastes context on the wrong problem.
Source: Observed failure pattern where agents skip task confirmation and start coding immediately.

---

### Workflow Step 2: Review project context

> "Read `project-spec.md` and relevant files."

Rationale: The project spec provides architectural patterns, structure, and conventions. Reading it before planning prevents the agent from proposing changes that conflict with established patterns.
Source: Implementation Rules reference section.

> "Review the code areas the task is likely to touch."

Rationale: The agent must verify that the code matches what the issue assumes. Issues are written against the author's mental model, which may be stale.
Source: Planning Requirements (treat issue implementation details as provisional).

> "Extract the intended outcome from the issue before using implementation suggestions."

Rationale: Separates the goal (what should change) from the means (how to change it). The goal is authoritative; the implementation suggestions need verification against the current codebase.
Source: Planning Requirements design decision.

---

### Workflow Step 3: Produce a code-aware plan

> "Write the plan."

Rationale: The plan exists as a checkpoint artifact that gives the human a concrete, reviewable description of what the agent intends to do before any code changes happen.
Source: Planning Requirements design decision.

---

### Workflow Step 4: Checkpoint - human reviews the plan

> "Update the plan if the human requests changes."

Rationale: The human checkpoint is a gate, not a formality. The agent must incorporate feedback rather than proceeding with the original plan.
Source: Workflow architecture (human checkpoints are explicit numbered steps).

---

### Workflow Step 5: Implement the approved scope

> "Implement the work defined in the approved plan."

Rationale: Scopes implementation to exactly what was approved. Prevents the agent from expanding scope during coding.
Source: Scope Control reference section.

---

### Workflow Step 6: Run validation

> "Run validation checks."

Rationale: Validation after every code change catches regressions immediately. Deferring validation allows errors to compound.
Source: Validation Requirements reference section.

---

### Workflow Step 7: Support manual verification

> "Suggest manual checks for the human."

Rationale: Automated tests cannot cover every user-facing path. The agent should identify what manual checks are needed and make them easy for the human.
Source: Manual Verification Requirements reference section.

---

### Workflow Step 8: Checkpoint - human reviews validation and manual verification

Rationale: Gate before the agent proceeds to fixes. The human may have observations the agent cannot detect.
Source: Workflow architecture.

---

### Workflow Step 9: Fix and revalidate

> "Fix reported issues."

Rationale: Directs the agent to address what the human identified during the checkpoint. Without this explicit instruction, the agent might only partially address feedback or prioritise easy fixes.
Source: Workflow architecture (human checkpoints produce actionable issues).

> "Rerun relevant validation checks after each fix."

Rationale: A fix can introduce new regressions. Re-validating after each fix prevents error compounding.
Source: Validation Requirements.

> "Repeat until no issues remain."

Rationale: Sets an explicit termination condition. Without it the agent may stop after one pass even when multiple issues were reported.
Source: Workflow architecture.

> "Enter Failure Analysis Mode if a fix fails." / "Enter Failure Analysis Mode if manual verification fails."

Rationale: Prevents the agent from cycling through speculative fixes. Manual verification failure means runtime contradicts the implementation. Forces structured reasoning before more code changes.
Source: Failure Analysis Mode design decision.

---

### Workflow Step 10: Summarise and prepare handoff

> "Report what changed."

Rationale: Gives the human a clear picture of the implementation for review.
Source: Workflow sequence.

> "Report what was tested."

Rationale: Establishes what the agent has validated, so the human knows what is covered.
Source: Validation Requirements (report what was tested and what passed).

> "Report what was not tested."

Rationale: Honest reporting prevents the human from assuming full coverage when there are gaps.
Source: Validation Requirements (do not claim code is tested when it is not).

> "Report remaining risks and follow-up work."

Rationale: The agent may have discovered problems outside the current scope. These should be surfaced, not silently dropped.
Source: Scope Control (flag larger problems as follow-up work).

> "Check parent and sub-issue closure status."

Rationale: Lets the human know whether completing this sub-issue closes the parent.
Source: Handling Parent and Sub-Issues reference section.

> "State which GitHub action would be next if the human wants to publish the work."

Rationale: Prepares the handoff. The agent proposes; the human decides.
Source: GitHub Workflow (treat commit, push, and PR as separate actions).

---

### Workflow Step 11: Checkpoint - human approves the next GitHub action

> "Stop after the summary until the human explicitly approves the next GitHub action in the current session."

Rationale: Prevents the agent from pushing code or creating PRs based on momentum. Each remote action requires explicit consent.
Source: Observed failure pattern where agents push and create PRs without confirmation.

---

### Workflow Step 12: Run the approved GitHub action and stop

> "Run only the single GitHub action the human explicitly approved."

Rationale: Prevents chaining (e.g. human approves a push, agent also creates a PR). Each action is a separate approval.
Source: GitHub Workflow (do not infer approval for one action from approval for another).

---

### Planning Requirements

> "State the branch the work will be implemented on."

Rationale: Makes the branch explicit in the plan so the human can verify it before coding starts.
Source: GitHub Workflow (do not work directly on main).

> "State the goal of the change in one or two sentences."

Rationale: Forces the agent to articulate the goal concisely. A plan without a clear goal cannot be reviewed.
Source: Planning Requirements design decision (plan is a checkpoint artifact).

> "State the user-visible behaviour that must change."

Rationale: Keeps the plan grounded in outcomes, not just code changes. The human can verify whether the right thing is being changed.
Source: Planning Requirements design decision.

> "State the files and code areas the change will touch."

Rationale: Gives the human a scope preview and forces the agent to verify these files exist and are the right targets.
Source: Planning Requirements (verify against current code, not issue assumptions).

> "State the proposed implementation approach."

Rationale: The reviewable core of the plan. The human can catch wrong approaches before they become wrong code.
Source: Planning Requirements design decision.

> "State any assumptions the plan depends on."

Rationale: Makes hidden assumptions explicit so the human can validate or challenge them.
Source: Planning Requirements design decision.

> "Separate issue assumptions from codebase-confirmed assumptions."

Rationale: Forces the agent to be explicit about what it knows versus what it is guessing. The human can spot wrong assumptions before they become wrong code.
Source: Planning Requirements design decision.

> "State how each critical assumption will be verified."

Rationale: An assumption without a verification plan is a guess that will not be caught until it fails in production.
Source: Planning Requirements design decision.

> "State any remaining uncertainties or ambiguities."

Rationale: Honest uncertainty reporting lets the human resolve ambiguities before coding starts, when it is cheapest.
Source: Boundary Rules (flag uncertainty explicitly).

> "State the risks and edge cases."

Rationale: Forces proactive risk identification rather than discovering edge cases during implementation or review.
Source: Planning Requirements design decision.

> "Mark the change as higher-risk if it affects routing, persistence, sync, caching, reactive subscriptions, or state transitions."

Rationale: These areas have non-local effects. A bug can appear correct locally but break a different screen or surface only after a delay.
Source: Planning Requirements design decision (higher-risk markers).

> "Include at least one runtime validation step for higher-risk changes."

Rationale: Higher-risk areas cannot be validated by unit tests alone. Runtime validation catches problems that only manifest in the full execution context.
Source: Planning Requirements design decision.

> "State the validation approach."

Rationale: Commits the plan to a specific validation strategy that the human can review.
Source: Validation Requirements reference section.

> "State any logging or observability changes needed."

Rationale: Logging decisions should be deliberate and planned, not afterthoughts during implementation.
Source: Logging and Observability reference section.

> "Treat the issue goal as authoritative."

Rationale: The goal (what should change) comes from the human who filed the issue. The agent should not second-guess the goal itself.
Source: Planning Requirements design decision.

> "Treat issue-suggested implementation details as provisional until the current codebase confirms them."

Rationale: Issues are written against the author's mental model, which may be stale or wrong. The agent must verify before trusting.
Source: Planning Requirements design decision.

> "Do not assume the files, data flow, or control points named in the issue are the real execution path."

Rationale: The issue may reference files that no longer exist or logic that has moved.
Source: Planning Requirements design decision.

> "If the issue and the current codebase disagree, prioritise the codebase and flag the mismatch to the human."

Rationale: First principle: the codebase provides implementation truth. The agent should not silently follow stale issue instructions.
Source: First Principles.

> "If the issue suggests a structure that the current codebase does not follow, plan against the real structure and flag the mismatch to the human."

Rationale: Planning against a structure that does not exist produces code that does not work.
Source: First Principles + Planning Requirements.

> "Keep the plan concise."

Rationale: Long plans waste context tokens and are harder for the human to review. Brevity forces precision.
Source: Context budget maintenance rule.

---

### Implementation Rules

> "Use `project-spec.md` for initial context on architectural patterns, project structure, and conventions."

Rationale: The project spec is the starting point for understanding the codebase. It prevents the agent from inventing patterns that conflict with existing ones.
Source: Implementation Rules reference section.

> "Prefer extending current patterns over introducing new ones."

Rationale: New patterns increase cognitive load and review burden. Consistency is cheaper than novelty.
Source: Implementation Rules reference section.

> "Keep changes focused and relevant to the approved plan."

Rationale: Scope control during implementation. The approved plan defines the boundary.
Source: Scope Control reference section.

---

### Scope Control

> "If the issue contains multiple unrelated objectives, flag this and ask the human whether to split them into separate tasks."

Rationale: Agents tend to pick the easiest objective and declare progress, leaving harder objectives partially addressed. Splitting forces each objective to be tracked independently.
Source: Scope Control design decision.

> "If the task would require changes across many unrelated areas of the codebase, flag the risk and suggest decomposition."

Rationale: Cross-cutting changes are harder to review, harder to test, and more likely to introduce regressions.
Source: Scope Control design decision.

> "Do only the work required to complete the task."

Rationale: The fundamental scope rule. Everything else in this section is a specific application of this principle.
Source: Scope Control design decision.

> "Do not treat 'while I am here' changes as free."

Rationale: Agents optimise for perceived completeness, leading to unrequested refactors and cosmetic changes that increase review burden and risk.
Source: Scope Control design decision.

> "Separate fixes, refactors, and feature work unless the task clearly requires them together."

Rationale: Mixing change types in one task makes review harder and makes it impossible to revert one type without reverting the others.
Source: Scope Control design decision.

> "If a larger problem is discovered, flag it as follow-up work instead of silently broadening the implementation."

Rationale: Silently broadening scope is the most common agent failure mode. Flagging preserves scope while ensuring the problem is not lost.
Source: Scope Control design decision.

---

### Validation Requirements: Baseline

> "Run smoke tests." / "Run the global test suite."

Rationale: Establishes the known-good baseline before implementation. Without this, regressions cannot be distinguished from pre-existing failures.
Source: Baseline Validation and Rebasing design decision.

> "Record which tests pass and which tests fail."

Rationale: The recorded baseline is the comparison point for post-implementation results.
Source: Baseline Validation and Rebasing design decision.

> "Treat any pre-existing failure as a known failure for the duration of the task."

Rationale: Prevents wasted time debugging failures the change did not cause.
Source: Baseline Validation and Rebasing design decision.

> "Do not attempt to fix pre-existing failures unless the task requires it."

Rationale: Fixing unrelated failures is scope drift and may introduce new problems.
Source: Scope Control.

> "If a test that passed in the baseline now fails, treat the change as the cause until proven otherwise."

Rationale: The default assumption should be that the change broke it. This prevents the agent from dismissing regressions.
Source: Baseline Validation and Rebasing design decision.

> "If a test that failed in the baseline still fails, do not attribute it to the change."

Rationale: Pre-existing failures should not block the current task or trigger unnecessary debugging.
Source: Baseline Validation and Rebasing design decision.

> "Report pre-existing failures separately from change-related failures."

Rationale: Mixed reporting makes it impossible for the human to assess the change's impact.
Source: Validation Requirements.

---

### Validation Requirements: Running validation

> "Run validation after every code change."

Rationale: Catching regressions immediately is cheaper than catching them after multiple changes have accumulated.
Source: Validation Requirements.

> "If repo-local deterministic policy requires a passed validation state before commit or push, satisfy that requirement through the repository validation flow."

Rationale: Connects the workflow instruction to the deterministic enforcement system. The agent should use the project's validation flow, not bypass it.
Source: Deterministic policy placement maintenance rule.

> "Confirm the app builds and starts without errors." (Smoke tests)

Rationale: The cheapest check. If the app does not build, nothing else matters.
Source: Validation Requirements.

> "Run the full existing test suite." (Global test suite)

Rationale: Catches regressions across the entire codebase, not just the changed area.
Source: Validation Requirements.

> "Run tests specific to the changed area." (Targeted tests)

Rationale: Targeted tests exercise the changed behaviour more thoroughly than the global suite.
Source: Validation Requirements.

> "If no targeted tests exist, flag this."

Rationale: Honest reporting. The human should know that the changed area has no dedicated test coverage.
Source: Validation Requirements (do not claim code is tested when it is not).

> "Add tests if the change introduces behaviour that existing tests do not cover."

Rationale: New behaviour without tests will have no safety net for future changes.
Source: Validation Requirements.

> "Run the new tests."

Rationale: Writing tests that are never run provides no validation signal. The explicit instruction ensures the agent executes them and confirms they pass.
Source: Validation Requirements.

> "Do not modify smoke tests or the global test suite unless the task explicitly requires it."

Rationale: Modifying tests to make them pass is a form of scope drift and can mask regressions.
Source: Scope Control + Boundary Rules (weakening or removing tests requires asking first).

> "Do not run validation commands in parallel when they can share ports, build outputs, caches, or runtime state."

Rationale: Parallel validation with shared state produces flaky, non-deterministic results that waste debugging time.
Source: Validation Requirements.

> "If a previously passing test fails after the change, treat the change as wrong until proven otherwise."

Rationale: The fundamental regression rule. Without this, agents dismiss failures and continue.
Source: Baseline Validation and Rebasing design decision.

> "Run smoke tests and the global test suite after each meaningful implementation pass."

Rationale: Frequent validation catches regressions close to the change that introduced them.
Source: Validation Requirements.

> "Do not treat passing smoke tests and the global test suite as proof that the requested behaviour works."

Rationale: Existing tests may not cover the new behaviour. Passing tests only prove nothing was broken, not that the feature works.
Source: Validation Requirements.

> "Treat existing passing tests as evidence of stability."

Rationale: Passing tests confirm the change did not break existing behaviour.
Source: Validation Requirements.

> "Do not treat existing passing tests as proof of correctness for new behaviour."

Rationale: New behaviour needs its own tests. Existing tests were not written to validate it.
Source: Validation Requirements.

> "If the change affects state transitions, sync, routing, caching, or reactive UI updates, include validation that follows the full user path."

Rationale: These areas have non-local effects that unit tests cannot catch. The full user path is the only reliable validation.
Source: Planning Requirements (higher-risk markers).

> "If no automated test exercises the real user path, say so explicitly."

Rationale: Honest reporting. The human needs to know when automated coverage is insufficient.
Source: Validation Requirements.

> "If manual verification fails, stop implementation mode and enter Failure Analysis Mode before making more code changes."

Rationale: Prevents speculative fix cycles. Forces structured diagnosis first.
Source: Failure Analysis Mode design decision.

---

### Validation Requirements: Reporting

> "Report what was tested and what passed."

Rationale: Basic accountability. The human needs to know the validation scope.
Source: Validation Requirements.

> "Report what failed and whether the failure is related to the change."

Rationale: Distinguishing change-caused failures from pre-existing ones prevents unnecessary debugging.
Source: Baseline Validation and Rebasing design decision.

> "Report what was not tested and why."

Rationale: Gaps in testing should be transparent so the human can decide whether additional verification is needed.
Source: Validation Requirements.

> "Report failures honestly, including failures unrelated to the change."

Rationale: Hiding failures undermines trust and prevents the human from tracking codebase health.
Source: Validation Requirements.

> "Do not claim code is tested when it is not."

Rationale: False claims of testing are worse than no testing because they suppress the human's review instinct.
Source: Validation Requirements.

> "Do not ignore failing tests and continue as if the task is complete."

Rationale: Ignoring failures and declaring success is a critical trust violation.
Source: Validation Requirements.

---

### Manual Verification Requirements

> "Suggest specific manual checks based on the change."

Rationale: Generic "test the feature" is not actionable. Specific checks tell the human exactly what to verify.
Source: Manual Verification Requirements.

> "State the success signal for each check."

Rationale: The human needs to know what "working" looks like to verify correctly.
Source: Manual Verification Requirements.

> "State the failure signal for each check."

Rationale: The human needs to know what "broken" looks like to catch regressions.
Source: Manual Verification Requirements.

---

### Failure Analysis Mode: Entry conditions

> "Enter failure analysis mode when manual verification fails."

Rationale: Manual verification failure means runtime behaviour contradicts the implementation. Speculative fixes without diagnosis make things worse.
Source: Failure Analysis Mode design decision.

> "Enter failure analysis mode when runtime behaviour contradicts the implementation."

Rationale: The contradiction itself is the signal, regardless of how it was discovered.
Source: Failure Analysis Mode design decision.

> "Enter failure analysis mode when test results conflict with observed behaviour."

Rationale: Tests saying one thing and observation saying another indicates a deeper problem that fix attempts will not resolve.
Source: Failure Analysis Mode design decision.

---

### Failure Analysis Mode: Procedure

> "Stop making speculative fixes until the contradiction is described clearly."

Rationale: The default agent behaviour is to immediately attempt fixes, making the problem worse. Stopping forces reasoning first.
Source: Failure Analysis Mode design decision.

> "State the observed behaviour in user terms." / "State the expected behaviour in user terms."

Rationale: Framing in user terms prevents the agent from describing the problem in code terms that obscure the actual failure.
Source: Failure Analysis Mode design decision.

> "Restate the contradiction in one short block before any reasoning."

Rationale: Forces the agent to articulate the problem clearly before attempting to solve it.
Source: Failure Analysis Mode design decision.

> "Use this format: observed behaviour, expected behaviour, strongest conflicting evidence, and what remains unknown."

Rationale: Structured format prevents the agent from skipping steps or burying contradictions in prose.
Source: Failure Analysis Mode design decision.

> "List the assumptions the implementation relied on." / "Mark each assumption as verified, unverified, or disproved."

Rationale: Makes hidden assumptions explicit and forces the agent to check which ones still hold.
Source: Failure Analysis Mode design decision.

> "List plausible failure causes across issue interpretation, code path selection, persistence, sync, caching, routing, UI binding, environment, test coverage, and observability."

Rationale: The checklist prevents tunnel vision. Without it, agents fixate on the first hypothesis and ignore alternatives.
Source: Failure Analysis Mode design decision (hypothesis-driven debugging).

> "Identify the cheapest next observation that can eliminate one or more hypotheses."

Rationale: Directs the agent toward the single observation that would eliminate the most hypotheses rather than cycling through random fixes.
Source: Failure Analysis Mode design decision.

> "If multiple hypotheses exist, prefer the next observation that distinguishes between wrong code path, wrong write, later overwrite, sync overwrite, and stale runtime."

Rationale: These are the most common competing explanations for state-related bugs. Distinguishing between them early saves debugging time.
Source: Failure Analysis Mode design decision.

> "Name the single leading hypothesis before proposing the next step."

Rationale: Forces commitment to a hypothesis, making the reasoning testable and the next step purposeful.
Source: Failure Analysis Mode design decision.

> "State the evidence that currently supports the leading hypothesis."

Rationale: Evidence-backed hypotheses are more likely correct than guesses. If the evidence is thin, that itself is useful information.
Source: Failure Analysis Mode design decision.

> "If repeated fixes under different hypotheses are not converging, state this clearly."

Rationale: Non-convergence is a signal that the approach is fundamentally wrong, not that the agent needs to try harder.
Source: Failure Analysis Mode design decision.

> "If investigation reveals that the plan was based on incorrect assumptions about the codebase, state this clearly."

Rationale: Admitting the plan was wrong is necessary to course-correct. Without this rule, agents try to preserve wrong plans.
Source: Failure Analysis Mode design decision.

> "Report what the plan assumed." / "Report what the codebase actually does." / "Report what a revised approach would need to account for."

Rationale: Structured disclosure of the gap between plan and reality, enabling the human to approve a revised approach.
Source: Failure Analysis Mode design decision.

> "If the contradiction involves a write, state transition, sync boundary, or reactive screen, prefer temporary diagnostics or direct observation over a retry request."

Rationale: Agents frequently ask the human to "try again" as a substitute for understanding what went wrong. Diagnostics produce evidence; retries often do not.
Source: Failure Analysis Mode design decision.

> "Gather evidence before proposing another fix."

Rationale: Prevents fix-without-diagnosis cycles.
Source: Failure Analysis Mode design decision.

> "Test at least one concrete hypothesis before asking the human to retry the flow, refresh the app, clear cache, restart the dev server, or repeat manual verification."

Rationale: Retry requests shift debugging effort to the human and often do not resolve the issue.
Source: Failure Analysis Mode design decision.

> "Prioritise code path, persistence, sync, routing, and UI binding explanations over environment or caching unless evidence shows otherwise."

Rationale: Environment and caching are convenient scapegoats but rarely the actual cause. Code-level explanations are more often correct.
Source: Failure Analysis Mode design decision.

> "Do not signal a flawed approach based on difficulty alone."

Rationale: Difficulty is not evidence of a wrong approach. Premature pivoting wastes the work already done.
Source: Failure Analysis Mode design decision.

> "Signal a flawed approach only when evidence shows the assumptions were wrong."

Rationale: The trigger for changing approaches should be evidence, not frustration.
Source: Failure Analysis Mode design decision.

---

### Logging and Observability: When to add logging

> "Decide whether additional logging or observability is needed when the change introduces user-facing flows, data writes, sync operations, state transitions, silently failing error handling paths, or integration points between layers."

Rationale: These are the areas where problems are hardest to diagnose after the fact. Logging here provides the most diagnostic value per line.
Source: Logging and Observability design decision.

---

### Logging and Observability: Adding logging

> "Use the project's existing logging approach."

Rationale: Consistency. Introducing a new logging pattern is scope drift.
Source: Boundary Rules (introducing new conventions requires asking first).

> "If no logging approach exists, flag this in the plan."

Rationale: Negative rules need a positive alternative. Flagging it lets the human decide rather than leaving the agent stuck.
Source: Maintenance rule (negative rules need a positive alternative).

> "Log the action, relevant identifiers, and outcome."

Rationale: The minimum useful log entry: action plus identifiers plus outcome is enough to trace a problem.
Source: Logging and Observability design decision.

> "Include enough context to trace a problem without a debugger."

Rationale: If the log requires a debugger to interpret, it has not saved any time.
Source: Logging and Observability design decision.

> "Do not add logging for trivial operations."

Rationale: Verbose logging obscures the meaningful entries and wastes output.
Source: Logging and Observability design decision (agents tend toward two extremes).

> "Do not add logging that would expose sensitive user data."

Rationale: Security boundary. Logs can be leaked through terminals, commits, or monitoring systems.
Source: Logging and Observability design decision.

> "Do not log full data payloads unless explicitly needed."

Rationale: Full payloads bloat logs and may contain sensitive data. Log identifiers and outcomes instead.
Source: Logging and Observability design decision.

> "If a change affects writes, sync behaviour, state transitions, or reactive screens, decide whether temporary diagnostic logging is needed to verify the runtime path."

Rationale: During development, the agent may need to prove which code path executed before the human can verify the feature works.
Source: Logging and Observability design decision (temporary diagnostics).

> "Prefer logs or probes that confirm which code path executed." / "Prefer logs or probes that confirm which identifiers were used." / "Prefer logs or probes that confirm which state transition occurred."

Rationale: These three pieces of information resolve the most common debugging questions for state-related bugs.
Source: Logging and Observability design decision.

> "If observability is too weak to distinguish between competing hypotheses, flag this before continuing."

Rationale: Continuing without sufficient observability means the next failure will be equally hard to diagnose.
Source: Logging and Observability design decision.

> "Remove temporary diagnostics before completion unless the human approves keeping them."

Rationale: Prevents debug logging from accumulating in the codebase across tasks.
Source: Logging and Observability design decision.

> "If a higher-risk change fails manual verification before the runtime path is proven, decide whether temporary diagnostics or another direct observation method is needed before asking the human to retry."

Rationale: Asking the human to retry without diagnostics produces no new information.
Source: Failure Analysis Mode + Logging and Observability design decisions.

---

### Logging and Observability: Investigation

> "Prefer automated diagnostics over asking the human to observe and report."

Rationale: Automated diagnostics are reproducible, structured, and do not burden the human with observation tasks the agent could handle.
Source: Logging and Observability design decision.

> "Write diagnostics that capture structured, non-sensitive output."

Rationale: Structured output is parseable by the agent. Non-sensitive output is safe to capture.
Source: Logging and Observability design decision.

> "Capture event types, state changes, control flow decisions, and timestamps when relevant."

Rationale: These are the data points that resolve most debugging questions.
Source: Logging and Observability design decision.

> "Run the diagnostic." / "Read the results." / "Use the results to drive the next step."

Rationale: Explicit sequencing prevents the agent from writing a diagnostic and then ignoring its output.
Source: Logging and Observability.

> "If a diagnostic cannot avoid capturing sensitive data, do not write it."

Rationale: Security boundary. No diagnostic is worth a data leak.
Source: Logging and Observability design decision.

> "Describe what to look for." / "Let the human observe it directly."

Rationale: The fallback when automated diagnostics cannot be made safe. The human observes; the agent does not capture sensitive data.
Source: Logging and Observability.

> "Only ask the human to provide logs or reproduce behaviour when automated observation is not possible."

Rationale: Automated observation is preferred because it is cheaper and more reliable. Human observation is the fallback.
Source: Logging and Observability design decision.

> "If only the human can trigger the condition, ask the human to trigger it and provide the raw output."

Rationale: Some conditions require human interaction. The agent should ask for raw output, not interpreted results.
Source: Logging and Observability.

> "Do not ask the human to interpret the results."

Rationale: Interpretation is the agent's job. Asking the human to interpret shifts cognitive burden without adding value.
Source: Logging and Observability.

> "Do not write diagnostics that output sensitive data, including tokens, credentials, PII, full payloads, or anything that could identify a real user."

Rationale: Comprehensive security boundary. The list is explicit to prevent the agent from rationalising exceptions.
Source: Logging and Observability design decision.

---

### Command Approval

> "State what the command does."

Rationale: The human needs to know the effect before approving. Without this, approval is uninformed consent.
Source: Command Approval design decision.

> "State why the command needs to run."

Rationale: Context for the approval decision. A command that is unnecessary should not be approved.
Source: Command Approval design decision.

---

### GitHub Workflow

> "Link every task to a GitHub issue before implementation."

Rationale: Without an issue, there is no scope boundary, no audit trail, and no way to track what was done.
Source: GitHub Workflow.

> "Do not work directly on `main`."

Rationale: Direct work on main bypasses review, breaks the branching model, and risks breaking the shared branch. Enforced deterministically by the pre-commit hook.
Source: Protected branch enforcement (.ai-policy/).

> "If the current branch is `main`, stop before implementation and create or switch to an issue-scoped branch."

Rationale: Positive alternative to "do not work on main". Tells the agent what to do, not just what not to do.
Source: Maintenance rule (negative rules need a positive alternative).

> "Do not edit files, run issue validation, or make commits until the issue-scoped branch is active."

Rationale: Any work done on the wrong branch has to be moved later, wasting time and risking errors.
Source: GitHub Workflow.

> "Use the branch naming format `type/short-description`."

Rationale: Consistent naming makes branches identifiable by purpose at a glance.
Source: GitHub Workflow convention.

> "Use `feature/` for new functionality." / "Use `fix/` for bug fixes." / "Use `refactor/` for refactors."

Rationale: Concrete branch type prefixes remove ambiguity about which prefix to use.
Source: GitHub Workflow convention.

> "Keep branch work focused on the issue scope."

Rationale: Scope control applied to branch content. A branch should contain one task's changes.
Source: Scope Control.

> "Rebase the issue branch onto the target branch before starting implementation."

Rationale: Ensures the starting point matches the current state of the target branch. Code written against a stale base can be silently wrong.
Source: Baseline Validation and Rebasing design decision.

> "Rebase the issue branch onto the target branch before creating a pull request."

Rationale: Ensures CI runs against the current target state, not a stale snapshot. Reduces merge conflicts after PR creation.
Source: Baseline Validation and Rebasing design decision.

> "If new commits have landed on the target branch since the last rebase, rebase again before the next remote GitHub action."

Rationale: Staleness can accumulate during implementation. The rebase must be fresh at the point of the remote action.
Source: Baseline Validation and Rebasing design decision.

> "If the task changes significantly during implementation, update the issue or flag the mismatch to the human."

Rationale: The issue is the scope contract. If implementation diverges, the issue must be updated or the human must be informed.
Source: Scope Control.

> "Treat commit creation, push to remote, and pull request creation as separate GitHub actions."

Rationale: Each remote action has different risk and reversibility. Bundling them removes the human's ability to approve incrementally.
Source: Observed failure pattern where agents push and create PRs without confirmation.

> "Confirm repo-local deterministic policy is active before relying on protected-branch or validation enforcement."

Rationale: If hooks are not installed, the deterministic safety net does not exist. The agent must verify before assuming it is protected.
Source: Deterministic policy placement maintenance rule.

> "If Git `core.hooksPath` is not `.githooks`, run `./.ai-policy/scripts/install-hooks.sh`."

Rationale: Recovery step. Tells the agent exactly what to do when hooks are not active.
Source: install-hooks.sh design decision.

> "Repo-local deterministic policy may block protected-branch Git actions and commit or push without passed validation."

Rationale: Informs the agent that deterministic enforcement exists so it does not interpret a blocked action as a mysterious error.
Source: Deterministic Policy System design decision.

> "Do not infer approval for one GitHub action from approval for another GitHub action."

Rationale: Prevents chaining. Approval for a commit does not imply approval for a push.
Source: Observed failure pattern where agents chain remote actions.

> "Do not push to remote without explicit human confirmation in the current session."

Rationale: Push affects shared state and is hard to reverse. Requires explicit, per-session consent.
Source: Observed failure pattern.

> "Do not create a pull request without explicit human confirmation in the current session."

Rationale: PR creation affects shared state and triggers notifications. Requires explicit consent.
Source: Observed failure pattern.

> "If deterministic policy blocks an action, fix the blocked condition before retrying."

Rationale: Retrying a blocked action without fixing the condition will just fail again. The agent should diagnose and fix (e.g. run validation).
Source: Deterministic Policy System design decision.

> "If new commits are added after approval, stop and ask again before the next remote GitHub action."

Rationale: New commits change what would be pushed. The human's approval was for the previous state.
Source: GitHub Workflow.

> "After running an approved GitHub action, stop and report the result."

Rationale: Prevents the agent from chaining further actions after completing one. The human should see the result and decide next steps.
Source: Workflow architecture (one action per approval).

---

### Handling Parent and Sub-Issues

> "Treat a parent issue as broader context that may list sub-issues."

Rationale: Frames the parent as context, not as a task to implement directly.
Source: Handling Parent and Sub-Issues design decision.

> "Treat a sub-issue as a single bounded work item."

Rationale: Sub-issues are the unit of work. Each one should be implementable in a single task.
Source: Handling Parent and Sub-Issues design decision.

> "If the provided issue is a parent issue with sub-issues, do not implement the full parent scope."

Rationale: Implementing the full parent scope would violate scope control. The parent may span multiple tasks.
Source: Scope Control + Handling Parent and Sub-Issues design decision.

> "If the provided issue is a parent issue with sub-issues, stop and ask which sub-issue to work on."

Rationale: Prevents the agent from picking a sub-issue arbitrarily. The human should choose.
Source: Handling Parent and Sub-Issues design decision.

> "If the provided issue is a sub-issue, read the parent issue and its comments for context."

Rationale: The parent provides broader context that may inform the sub-issue implementation.
Source: Handling Parent and Sub-Issues design decision.

> "If the provided issue is a sub-issue, do not read further up the hierarchy."

Rationale: Prevents the agent from spending context window on distant ancestors that provide diminishing context.
Source: Handling Parent and Sub-Issues design decision.

> "If the provided issue is a sub-issue, implement only the sub-issue scope."

Rationale: Scope control. The sub-issue defines the boundary.
Source: Scope Control.

> "If the provided issue has no sub-issues, treat it as a standalone work item."

Rationale: Handles the common case where issues are flat, not hierarchical.
Source: Handling Parent and Sub-Issues.

> "When completing a sub-issue, check whether it is the last open sub-issue under the parent."

Rationale: Convenience signal so the human knows when a larger piece of work is done.
Source: Handling Parent and Sub-Issues design decision.

> "If the completed sub-issue is the last open sub-issue under the parent, flag this to the human."

Rationale: The human may want to close the parent or review the full body of work.
Source: Handling Parent and Sub-Issues design decision.

---

### Boundary Rules: Always Do

> "Follow the workflow steps in order."

Rationale: The workflow is a sequence, not a menu. Skipping steps leads to missing inputs or unvalidated output.
Source: Workflow architecture.

> "Stop and ask when anything is unclear, risky, or out of scope."

Rationale: The agent should not guess through ambiguity. Guessing introduces errors that are caught late at review rather than early at planning.
Source: Boundary Rules design decision (unconditional process requirements).

> "Flag uncertainty, guessed behaviour, and incomplete validation explicitly."

Rationale: Honest reporting. The human cannot compensate for problems they do not know about.
Source: Boundary Rules design decision.

> "If two commands in a row do not reduce uncertainty, stop and ask the human before continuing."

Rationale: Non-converging investigation is a signal that the agent is stuck and needs human input rather than more random attempts.
Source: Failure Analysis Mode design decision (non-convergence signal).

---

### Boundary Rules: Ask First

> "Adding a new dependency."

Rationale: Dependencies are hard to remove, affect build size and security surface, and may conflict with project constraints.
Source: Boundary Rules design decision (hard to reverse, non-local consequences).

> "Changing architecture or established patterns."

Rationale: Architecture changes affect the entire codebase and require deliberate human decision-making.
Source: Boundary Rules design decision.

> "Changing database schema or sync-related behaviour."

Rationale: Schema changes are among the hardest to reverse and can break data integrity.
Source: Boundary Rules design decision.

> "Changing public interfaces or shared contracts."

Rationale: Public interfaces affect consumers who may not be visible to the agent.
Source: Boundary Rules design decision.

> "Making broad refactors."

Rationale: Broad refactors touch many files, increase review burden, and risk regressions across the codebase.
Source: Boundary Rules design decision.

> "Deleting files or removing significant code paths."

Rationale: Deletion is hard to reverse and may remove functionality that is not obviously referenced.
Source: Boundary Rules design decision.

> "Weakening, skipping, or removing tests."

Rationale: Tests are a safety net. Weakening them to make the change pass is a dangerous shortcut.
Source: Boundary Rules design decision.

> "Introducing new conventions or changing existing ones."

Rationale: Conventions affect every future change and should be deliberate human decisions.
Source: Boundary Rules design decision.

> "Introducing a new logging library or pattern."

Rationale: Logging patterns should be consistent across the codebase. A new one fragments the approach.
Source: Logging and Observability design decision.

> "Making assumptions where the task or expected behaviour is unclear."

Rationale: An assumption made silently becomes wrong code. An assumption made explicitly becomes a question.
Source: Boundary Rules design decision.

> "Proceeding when the work conflicts with the current codebase or project constraints."

Rationale: Conflicts should be surfaced, not overridden. The human may have context the agent lacks.
Source: Boundary Rules design decision.

---

### Boundary Rules: Never Do

> "Invent requirements not present in the task or project context."

Rationale: Invented requirements are scope drift by definition. The agent should implement what was asked, not what it thinks should be asked.
Source: Scope Control design decision.

> "Silently expand scope or introduce unrelated changes."

Rationale: The most common agent failure mode. Silent expansion undermines the human's ability to review and control the work.
Source: Scope Control design decision.

> "Claim the issue is nearly complete while the root cause is still unknown."

Rationale: False progress signals prevent the human from intervening when intervention is needed.
Source: Failure Analysis Mode design decision.

> "Hardcode sensitive values."

Rationale: Hardcoded secrets in code are a security vulnerability that persists in version history.
Source: Security boundary.

> "Bypass deterministic policy checks or treat them as optional."

Rationale: Deterministic policy exists because instruction-following alone is unreliable. Bypassing it defeats the safety net.
Source: Deterministic Policy System design decision.

---

### The Human is Responsible For

> "Define and scope the task before it reaches the AI."

Rationale: The agent works within the scope it is given. If the scope is wrong, the work will be wrong.
Source: Human Responsibilities design decision (boundary of agent authority).

> "Decompose larger work into sub-issues and provide a sub-issue rather than the parent as the starting input."

Rationale: The agent should not decompose work. Decomposition is a design decision that belongs to the human.
Source: Handling Parent and Sub-Issues design decision.

> "Provide a well-formed GitHub issue as the starting input."

Rationale: The workflow starts from an issue. A missing or poorly formed issue means the agent has no clear target.
Source: Workflow Step 1.

> "Ensure the right project context is available."

Rationale: The agent reads what is available. If project-spec.md is missing or stale, the agent's understanding will be wrong.
Source: Human Responsibilities design decision.

> "Review and approve the plan before coding starts."

Rationale: The plan checkpoint exists to catch wrong approaches early. If the human does not review, the checkpoint is wasted.
Source: Workflow architecture (human checkpoints).

> "Monitor for scope drift during implementation."

Rationale: The agent has rules against scope drift, but the human is the ultimate check. Agents can rationalise expansion.
Source: Scope Control design decision.

> "Perform manual verification where automated tests are not sufficient."

Rationale: Some behaviour can only be verified by a human observing the running application.
Source: Manual Verification Requirements.

> "Report issues found during review or testing."

Rationale: The agent cannot see what the human sees during manual verification. Reported issues drive the fix-and-revalidate loop.
Source: Workflow Step 9.

> "Decide when the work is complete."

Rationale: Completion is a human judgment. The agent should not declare its own work done.
Source: Human Responsibilities design decision.

---

## Deterministic Policy System (.ai-policy/)

### Why deterministic enforcement exists

The workflow file instructs the agent, but instruction compliance degrades as context grows and task complexity increases.
Bright-line mechanical rules (do not commit on a protected branch, do not commit without passing validation) are too important to rely on instruction-following alone.
The `.ai-policy/` directory moves these rules into deterministic enforcement: shell scripts that block the action at the Git level regardless of whether the agent remembered the rule.

This follows the maintenance rule "When a rule has both an advisory form and an enforcement form, keep the advisory form once in `ai-workflow.md` and keep the enforcement form in repo-local deterministic policy."
The advisory form helps the agent plan correctly; the deterministic form catches it when it does not.

### Why policy.env exists

`policy.env` centralises configuration for the policy system in one file.
Protected branch names, validation toggle flags, state file paths, and the validation command are all defined here.
This avoids scattering configuration across multiple scripts and makes it easy for a human to see or change the policy in one place.
Scripts source this file rather than hardcoding values.

### Protected branch enforcement

`check-protected-branch.sh` blocks commits and pushes to branches listed in `PROTECTED_BRANCHES`.
This enforces the workflow rule "Do not work directly on `main`" at the Git level.
The agent may forget or rationalise working on main; the hook will not.

### Validation state tracking

The validation system uses a simple state file (`validation.status`) with three states: `running`, `passed`, `failed`.

`run-validation.sh` orchestrates the flow: it sets the state to `running`, runs the configured validation command, and sets the state to `passed` or `failed` based on the result.
The `running` state plus a trap on exit ensures that if the script is interrupted or crashes, the state reverts to `failed` rather than remaining `passed` from a stale run.

`check-validation.sh` reads the state file and blocks the Git action unless the state is `passed`.
This enforces the workflow rule that validation must pass before commit or push.

`mark-validation-pass.sh` and `mark-validation-fail.sh` exist as manual overrides.
They allow the human to set validation state directly when the automated flow is not appropriate (e.g. the project has no tests yet, or a known-failing test needs to be bypassed for a specific commit).
These are escape hatches, not normal workflow paths.

### project-validation.sh

`project-validation.sh` is the validation command that `run-validation.sh` invokes.
In this repository it runs `bash -n` (syntax check) on all scripts in `.ai-policy/scripts/` and `.githooks/`.
In an adopting project, this file would be replaced with the project's actual test and build commands.
The indirection through `VALIDATION_COMMAND` in `policy.env` means the validation system works without modifying any script other than `project-validation.sh` (or changing the command path in `policy.env`).

### current-branch.sh

`current-branch.sh` is a one-line helper that returns the current branch name.
It exists as a separate script so that `check-protected-branch.sh` does not embed Git plumbing directly, keeping each script focused on a single concern.

### install-hooks.sh

`install-hooks.sh` sets `core.hooksPath` to `.githooks` and makes all scripts executable.
This is a one-time setup step per clone.
The workflow references it as a recovery step: if hooks are not active, run this script.
Using `core.hooksPath` instead of copying hooks into `.git/hooks/` means the hooks are version-controlled and shared across clones.

## Git Hooks (.githooks/)

### Why hooks are in .githooks/ not .git/hooks/

`.git/hooks/` is local and not version-controlled.
`.githooks/` is committed to the repository, which means every clone gets the same enforcement.
`install-hooks.sh` configures Git to use this directory via `core.hooksPath`.

### pre-commit hook

The pre-commit hook runs two checks in order:
1. Protected branch check: blocks the commit if on a protected branch.
2. Validation check (if enabled): blocks the commit if validation has not passed.

The protected branch check runs first because it is the cheaper operation and the more fundamental violation.
There is no point checking validation status if the commit should not happen on this branch at all.

### pre-push hook

The pre-push hook mirrors the pre-commit hook structure: protected branch check first, then validation check.
This provides a second enforcement point at push time.
Even if an agent or human bypasses pre-commit (e.g. with `--no-verify`), the push hook catches it.
Having both hooks means the feedback is early (at commit time) but the enforcement is redundant (at push time).

### Why both hooks exist

Pre-commit gives fast feedback: the agent learns immediately that it cannot commit without validation.
Pre-push provides a safety net: if pre-commit was bypassed, the invalid state does not reach the remote.
The cost of running both is negligible (two shell script invocations), and the benefit is defence in depth.

---

## Observed AI Failings

Use `observed-ai-failings.md` file to record concrete AI-agent failure patterns seen in real sessions.
Keep entries short.
Write one sentence per line.
Record what happened, not theories unless they are useful.

---

## Entry Template

### Title
- [Short name for the failure pattern.]

### Date
- [YYYY-MM-DD]

### Context
- [Tooling or environment, e.g. VS Code Copilot, ChatGPT app, CLI agent.]
- [Model if known, e.g. GPT-5.4.]
- [Repo or project if relevant.]

### What Happened
- [Describe the observed behaviour in one sentence.]
- [Add one more sentence only if needed.]

### Why It Matters
- [State the practical cost or risk in one sentence.]

### Trigger Pattern
- [State what seemed to trigger it in one sentence.]
- [Use "Unknown" if unclear.]

### Early Warning Signs
- [List the first visible sign.]
- [List the second visible sign if useful.]

### Scope
- [State whether this seems local to one workflow step or general across tasks.]
