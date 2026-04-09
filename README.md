# AI Coding Workflow

Project-agnostic workflow and maintenance documents for AI-assisted coding.

This repository provides a small set of files that help a human maintain consistent guardrails for an AI coding agent across repositories.
The workflow is written for the agent.
The design decision files are written for the human maintainer.

## Repository Contents

- `ai-workflow.md`: Canonical workflow for AI-assisted coding tasks, including planning, checkpoints, validation, failure analysis, and GitHub handoff rules.
- `ai-workflow-design-decisions.md`: Maintenance rules and structural rationale for editing `ai-workflow.md`.
- `project-spec-template.md`: Template for creating a `project-spec.md` file in a target repository.
- `project-spec-design-decisions.md`: Maintenance rules for keeping `project-spec.md` factual, concise, and aligned with implementation truth.
- `observed-ai-failings.md`: Log of concrete failure patterns observed in real AI-agent sessions.
- `.claude/skills/failure-analysis/SKILL.md`: Step-by-step process for investigating contradictions between implementation and runtime behaviour (also mirrored in `.github/skills/`).

## Intended Use

Use this repository as a source of reusable governance files for another software project.

Typical setup:

1. Copy `ai-workflow.md` into the target repository and load it through that repository's AI-agent instructions.
2. Create `project-spec.md` in the target repository from `project-spec-template.md`.
3. Use the two design decision documents when refining either file.
4. Record repeated real-world agent failure patterns in `observed-ai-failings.md`.

## What This Repository Optimizes For

- Clear human checkpoints before risky transitions.
- Plans grounded in the current codebase instead of issue assumptions.
- Validation discipline with baseline and post-change comparison.
- Tight scope control to reduce unapproved or opportunistic changes.
- Lightweight maintenance rules that keep agent-facing files concise.

## Maintenance Notes

- Keep agent-facing files short enough to preserve context budget.
- Treat the codebase and runtime behavior of the target repository as the source of truth.
- Prefer concrete instructions over abstract guidance.
- Update templates and workflow files when repeated failure patterns justify a rule change.

## AI Policy Hooks

This repo includes a lightweight local policy layer in `.ai-policy/` and `.githooks/`.

Current protections:

- block commit on protected branches
- block push on protected branches
- require a passed validation status before commit
- require a passed validation status before push

Setup:

```bash
./.ai-policy/scripts/install-hooks.sh
```

Run validation through the policy wrapper:

```bash
./.ai-policy/scripts/run-validation.sh
```

The validation state file is local runtime state and should not be committed.
