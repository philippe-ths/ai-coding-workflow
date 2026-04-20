# Maintenance Operations — AI Workflow Design Decisions

Covers how much to include in `ai-workflow.md`, versioning, file splitting, session logs, and the reusable maintenance prompt.

## Version Number

**Version number.**
The `Version:` header in `ai-workflow.md` is the canonical version for the project.
It tracks changes that affect how AI coding agents behave when the shipped files are installed in a target repository.
No other file holds a release-level version number; subordinate files (for example `lite-monolithic/ai-workflow.md`) carry this same version so they can be identified against the canonical anchor, but they are not independent sources of truth.

A change requires a version bump if it affects agent behaviour in a target repo.
Files whose changes require a bump:

- `ai-workflow.md` (workflow steps, rules, reference sections).
- Skill files in `.agents/skills/` and `.claude/skills/`.
- Policy scripts and hooks in `.ai-policy/`, `.githooks/`, and agent hook configurations.
- Agent entry points (`.github/copilot-instructions.md`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`).
- `lite-monolithic/ai-workflow.md`.

Files whose changes do not require a bump:

- Design decisions in `design/` — maintenance docs for this repo, not shipped to target repos.
- `project-context.md` in this repo — this repo's own context document, not shipped. Only bump if the `aiw-project-context-management` skill changes.
- `README.md`, `observations/`, test scripts — not shipped as workflow instructions.

Bump the patch version (Z) for any change that corrects wording, fixes a gap, or removes duplication without altering intent.
Bump the minor version (Y) for any change that adds a new rule, section, skill, policy enforcement, or meaningful constraint.
Bump the major version (X) for a structural overhaul that changes the number or order of workflow steps, or fundamentally restructures the skill or policy layer.
Update the version on every qualifying edit so session logs can be tied to a specific file state.

Every change to the `Version:` header requires a matching entry in `CHANGELOG.md` at the repo root. The pre-push hook (`.ai-policy/hooks/check-changelog.sh`) rejects pushes that bump the version without adding a matching entry. The changelog follows [Common Changelog](https://common-changelog.org/).

**Tagged releases.**
Create a tagged release for any minor or major version bump.
Patch bumps do not require a tagged release unless they fix a defect that users need to identify by version.

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

Extracted files live in two skill directories: `.agents/skills/` (cross-platform, for VS Code Copilot, Gemini CLI, Codex) and `.claude/skills/` (Claude Code).
Both directories contain the same skills. When editing any skill, apply the change to both directories.
Each skill is self-contained in a `SKILL.md` file within a named subdirectory (e.g. `.agents/skills/aiw-planning/SKILL.md`).
In the core workflow, use this exact loading instruction pattern: `Load the <name> skill.`
For example: `Load the aiw-planning skill.`
Core workflow skills use the `aiw-` prefix to avoid name collisions with project-specific or third-party skills in target repositories.
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
