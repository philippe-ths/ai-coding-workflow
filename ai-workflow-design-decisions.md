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
Do not explain why a rule exists.
The file instructs. It does not teach, persuade, or justify.
Rationale wastes tokens and the agent does not need to agree with a rule to follow it.

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
List each material observation, decision, proposed wording change, accepted change, rejected change, and file edit in order.
List any rules you clearly ignored in ai-workflow.md
Separate applied changes from ideas that were discussed but not adopted.
Omit filler chat and low-signal tool output.
Record brief failure-mode context when relevant, including agent surface, model, repo, and trigger pattern if known.
Do not use tables.
```

## Cross-Contamination Categories

When reviewing the file for structural problems, classify each line as one of:

- **OK.** Line is in the right place.
- **Cross-contaminated.** Content type does not match the section's purpose (e.g. a rule in the preamble, a principle in a workflow step).
- **Redundant.** The same rule is stated in multiple places.
- **Misplaced.** The line belongs in a different specific section (e.g. a human responsibility in a workflow step).
- **Candidate to move.** The line could be offloaded to a reference section with a pointer left behind.


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
