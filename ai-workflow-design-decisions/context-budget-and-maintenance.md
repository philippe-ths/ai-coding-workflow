# Context Budget and Maintenance Operations — AI Workflow Design Decisions

Covers how much to include in `ai-workflow.md`, versioning, file splitting, session logs, and the reusable maintenance prompt.

## Context Budget

**Context budget.**
Every line in the file consumes context window tokens that compete with the actual task.
Research suggests frontier models reliably follow roughly 150-200 instructions, with degradation uniform across all rules as the count increases.
The agent tool's own system prompt already consumes some of this budget before the workflow file loads.
This means every low-value line added dilutes the compliance probability of every high-value line.
Before adding a rule, ask: could the agent figure this out by reading the codebase?
If yes, do not add it.
If a boundary is bright-line and machine-checkable, prefer deterministic repo-local enforcement over repeated workflow wording.
Prefer fewer, higher-quality rules over comprehensive coverage.

## Version Number

**Version number.**
The workflow file carries a `Version: X.Y.Z` line in the preamble.
Bump the patch version (Z) for any change that corrects wording, fixes a gap, or removes duplication without altering the workflow's intent.
Bump the minor version (Y) for any change that adds a new rule, section, or meaningful constraint.
Bump the major version (X) for a structural overhaul that changes the number or order of workflow steps.
Update the version on every edit so session logs can be tied to a specific file state.

## Session Logs

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

Extracted files live in agent-specific skill directories: `.claude/skills/` for Claude Code and `.github/skills/` for Copilot.
Each skill is self-contained in a `SKILL.md` file within a named subdirectory (e.g. `.claude/skills/planning/SKILL.md`).
In the core workflow, use this exact loading instruction pattern: `Load the <name> skill.`
For example: `Load the planning skill.`
The loading instruction names the skill; the agent's native skill system handles discovery.

## Reusable Prompt

Use this prompt when requesting a chronological session log for workflow maintenance.

```text
Produce a chronological log of this chat session for maintenance of the file ai-workflow.md.
List the following: 
- [Tooling or environment, e.g. VS Code Copilot, ChatGPT app, CLI agent.]
- [AI Workflow Version] 
- [Model if known, e.g. GPT-5.4.]
- [Repo or project.]
List each material observation, decision, proposed wording change, accepted change, rejected change, and file edit in order.
List any rules you clearly ignored in ai-workflow.md
Separate applied changes from ideas that were discussed but not adopted.
Omit filler chat and low-signal tool output.
Do not use tables.
```
