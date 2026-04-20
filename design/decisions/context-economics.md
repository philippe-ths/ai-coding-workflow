# Context Economics

Covers the context budget constraints that govern what goes into `ai-workflow.md` and how progressive disclosure through reference sections and skills reduces the always-loaded token cost.

## Context budget

Every line in the file consumes context window tokens that compete with the actual task.
Research suggests frontier models reliably follow roughly 150-200 instructions, with degradation uniform across all rules as the count increases.
(See `design/research/token-efficiency-in-agentic-workflows.md#ifscale-instruction-compliance-decay`.)
The agent tool's own system prompt already consumes some of this budget before the workflow file loads.
This means every low-value line added dilutes the compliance probability of every high-value line.
Before adding a rule, ask: could the agent figure this out by reading the codebase?
If yes, do not add it.
If a boundary is bright-line and machine-checkable, prefer deterministic repo-local enforcement over repeated workflow wording.
Prefer fewer, higher-quality rules over comprehensive coverage.

## Progressive disclosure via lean steps

Workflow steps should be lean: sequenced actions and pointers to reference sections, not inline detail.
If a line in a workflow step reads like a rule rather than a sequenced action, it probably belongs in a reference section or boundary section.
This keeps the always-loaded step list short and defers the token cost of detailed rules to the reference sections that are only parsed when the step points to them.
Long context degrades retrieval and instruction adherence even when the content is present.
(See `design/research/token-efficiency-in-agentic-workflows.md#chroma-context-rot`.)

## Skill loading as a context budget tool

Skills are the on-demand variant of reference sections.
A section qualifies for extraction to a skill when it activates under a specific identifiable condition, is self-contained, and is not needed during the majority of sessions.
Extracting a section to a skill means its token cost is paid only in the sessions that need it.
For how to configure and sequence skill loading, see `design/decisions/runtime-configuration.md`.
Subagent context isolation is a stronger form of this tool: spawning a subagent for a bounded subtask gives it a clean context window with no accumulated session noise.
For when to use subagents and which tool knobs apply, see `design/decisions/runtime-configuration.md`.
