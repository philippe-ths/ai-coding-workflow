# Design Decisions

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
Three tiers: Always Do, Ask First, Never Do.

**Human responsibilities.**
What the AI cannot do.
This exists so the agent knows where to stop and hand off.

## Maintenance Rules

**One canonical location per rule.**
Every rule should exist in exactly one place.
If the same rule appears in two sections, decide which section owns it and remove the other.
Duplication causes drift over time and wastes context tokens.

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
Prefer fewer, higher-quality rules over comprehensive coverage.

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

## Cross-Contamination Categories

When reviewing the file for structural problems, classify each line as one of:

- **OK.** Line is in the right place.
- **Cross-contaminated.** Content type does not match the section's purpose (e.g. a rule in the preamble, a principle in a workflow step).
- **Redundant.** The same rule is stated in multiple places.
- **Misplaced.** The line belongs in a different specific section (e.g. a human responsibility in a workflow step).
- **Candidate to move.** The line could be offloaded to a reference section with a pointer left behind.

## Version History Context

The file has been through multiple rounds of refinement.
Key iterations:

- v1: Single monolithic file with rules, principles, and workflow mixed together.
- v2: Separated into preamble, first principles, workflow, reference sections, boundary rules, and human responsibilities. Deduplicated rules. Removed AI responsibilities section (was a restatement of the workflow). Consolidated boundary rules under one heading. Made workflow steps lean with pointers to reference sections. Moved issue-vs-codebase rules to Planning Requirements. Moved failure analysis rules out of workflow steps.