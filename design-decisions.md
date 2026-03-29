# Design Decisions

This document captures the structural principles and design rationale behind `ai-workflow.md`.
It is for the human maintainer, not for the AI agent.
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
The governing truths that override everything else.
If a rule elsewhere conflicts with a first principle, the first principle wins.
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
Global rules that apply across all tasks and all sections.
Three tiers: Always Do, Ask First, Never Do.
These are the canonical location for boundary rules.
If a boundary rule also appears in a reference section, remove it from the reference section and keep it here.

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
Where a second sentence is a continuation of the same conditional (e.g. "If X, do Y. / Do not do Z."), indent it under the same bullet rather than creating a new bullet.

**No em-dashes.**

**Workflow steps should be lean.**
A workflow step should contain sequenced actions and pointers to reference sections.
It should not contain detailed rules, principles, or human responsibility statements.
If a line in a workflow step reads like a rule rather than a sequenced action, it probably belongs in a reference section or boundary section.

**Human responsibilities do not belong in workflow steps.**
Lines describing what the human does (e.g. "Human reviews the results") should not appear inline in workflow steps.
Human checkpoints are expressed as explicit numbered steps (e.g. "Checkpoint: human reviews the plan.").
Detailed human responsibilities live in the Human Responsibilities section.

**Reference sections should not restate boundary rules.**
If a reference section contains a rule that is also in Always Do, Ask First, or Never Do, remove it from the reference section.
The boundary section is the canonical location.

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