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
Include rationale for judgment-heavy rules with ambiguous boundaries, where the agent needs to understand the purpose to avoid violating the spirit.
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

**No emphasis formatting for priority.**
Do not use bold, caps, or exclamation marks to signal that a rule is more important.
LLMs do not reliably weight formatting as priority.
If a rule is critical, put it earlier in the file or in First Principles.
Position in the file is a more reliable priority signal than formatting.

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

## Reusable Prompt

Use this prompt when requesting a chronological session log for workflow maintenance.

```text
Produce a chronological log for maintenance of the file ai-workflow.md.
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


## First Principles

The two first principles exist to prevent a class of failure where the agent trusts documentation, issue descriptions, or its own prior assumptions over what the code actually does and how it actually behaves.

"The codebase provides implementation truth" means the agent should resolve ambiguity by reading the code, not by re-reading the issue or guessing from file names.
"Runtime behaviour is the final source of truth" means that if the code says one thing and runtime says another, runtime wins.
This ordering prevents the agent from declaring a task complete because the code looks correct while the feature is actually broken.

## Planning Requirements

The plan exists as a checkpoint artifact, not as a task management document.
Its purpose is to give the human a concrete, reviewable description of what the agent intends to do before any code changes happen.

Treating the issue goal as authoritative but implementation details as provisional addresses a common failure: issues are written against the author's mental model of the codebase, which may be stale or wrong.
The agent must extract what should change from the issue but verify how to change it against the current code.
If the issue says "edit file X" but file X no longer exists or the logic has moved, the agent should plan against reality and flag the mismatch rather than blindly following the issue.

Separating issue assumptions from codebase-confirmed assumptions forces the agent to be explicit about what it knows versus what it is guessing.
This makes the plan reviewable: the human can spot wrong assumptions before they become wrong code.

Higher-risk markers (routing, persistence, sync, caching, reactive subscriptions, state transitions) exist because these areas have non-local effects.
A bug in a utility function is usually caught by a failing test.
A bug in sync or state transitions can appear correct locally but break a different screen or surface only after a delay.

## Scope Control

Scope control exists to prevent the most common form of AI scope drift: "while I am here" improvements.
Agents naturally optimise for perceived completeness, which leads to unrequested refactors, extra error handling, and cosmetic changes that increase review burden and introduce risk.
The rules are deliberately blunt because nuanced scope guidance gives the agent room to rationalise expansion.

Splitting unrelated objectives within a single issue prevents a different failure mode: the agent picks the easiest objective, declares progress, and the harder objective gets lost or partially addressed.

## Failure Analysis Mode

Failure analysis mode exists because the default agent behaviour when something breaks is to immediately attempt a fix, then another fix, then another, often making the problem worse or masking the root cause.
The structured format forces the agent to stop, describe the contradiction, and reason about causes before writing more code.

The hypothesis-driven structure (observed vs expected, assumptions checked, plausible causes, cheapest next observation) comes from debugging methodology.
It prevents the agent from cycling through random fixes and instead directs it toward the single observation that would eliminate the most hypotheses.

The rule about preferring diagnostics over asking the human to retry exists because agents frequently ask the human to "try again" or "clear the cache" as a substitute for understanding what went wrong.
This shifts debugging effort to the human and often does not resolve the issue.

## Logging and Observability

This section exists because agents tend toward two extremes: either adding no logging at all, or adding verbose logging everywhere.
The rules guide toward targeted logging at meaningful boundaries (writes, sync, state transitions) where problems are hardest to diagnose after the fact.

The emphasis on temporary diagnostics addresses a specific workflow need: during development, the agent may need to prove which code path executed or which state transition occurred before the human can verify the feature works.
Requiring removal before completion prevents debug logging from accumulating in the codebase.

The prohibition on sensitive data in diagnostics is a security boundary, not a style preference.
Diagnostics are often printed to terminals, committed accidentally, or left in logs.

## Command Approval

Command approval is a minimal transparency rule.
Agents run commands that can modify state, consume resources, or produce side effects.
Stating what a command does and why it needs to run gives the human the minimum information needed to approve or reject it.
This is deliberately lightweight because making it heavier would slow every task.

## Handling Parent and Sub-Issues

This section exists because GitHub issue hierarchies create an ambiguity: when given a parent issue, should the agent implement all of it or just part of it?
Without explicit rules, agents tend to treat a parent issue as a single task and attempt the full scope, which violates scope control.

The rule to stop and ask which sub-issue to work on prevents the agent from picking one arbitrarily.
The rule to read one level up (parent) but not further prevents the agent from spending its context window on distant ancestors that provide diminishing context.

Checking whether the completed sub-issue is the last open one under the parent is a convenience signal for the human to know when a larger piece of work is done.

## Boundary Rules

The three-tier structure (Always Do, Ask First, Never Do) exists to separate rules by enforcement weight.

"Always Do" rules are unconditional process requirements.
They apply to every task regardless of context.
They are things the agent should do automatically without prompting.

"Ask First" rules define actions the agent may take but only with explicit human approval.
These are actions that are individually reasonable but carry risk: adding dependencies, changing architecture, deleting code.
The common thread is that these actions are hard to reverse or have non-local consequences.

"Never Do" rules are bright-line prohibitions.
They exist because some actions are never acceptable regardless of context, and an agent that reasons about them case-by-case will eventually rationalise an exception.
The list is deliberately short: only include rules where zero tolerance is warranted.

## Human Responsibilities

This section exists to define the boundary of the agent's authority.
Without it, agents tend to gradually absorb responsibilities that belong to the human: deciding scope, judging completeness, approving their own work.

Listing human responsibilities explicitly also serves as a checklist for the human.
If the agent is making poor decisions, the human can check whether they failed to provide one of their inputs (e.g. a well-formed issue, sufficient project context).

## Baseline Validation and Rebasing

### Why rebase at the start of a task

Working on a stale branch means the agent writes code against an outdated state.
Files may have moved, APIs may have changed, or new conflicts may have accumulated.
Code that is correct against the old state can be silently wrong against current main.
Rebasing before implementation ensures the starting point matches reality.

### Why rebase before creating a pull request

The target branch may have moved forward during implementation.
Rebasing before the PR ensures CI runs against the current target state, not a stale snapshot.
It also reduces the chance of merge conflicts appearing after the PR is created.

### Why run a baseline test suite before implementation

The workflow rule "If a previously passing test fails after the change, treat the change as wrong until proven otherwise" is unenforceable without a known-good baseline.
Without a baseline, neither the human nor the agent can distinguish a regression from a pre-existing failure.
Both will naturally assume the change caused the failure, leading to wasted time debugging something that was already broken.
Running smoke tests and the global test suite after rebasing but before implementation establishes the comparison point.
Pre-existing failures are recorded so they can be excluded from post-implementation blame.

### Why the baseline runs after rebasing

The baseline must reflect the true starting state.
If the baseline ran before rebasing, it would validate a stale branch state that the implementation will never build on.
The sequence is: rebase, then baseline, then implement.

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
