# Project Spec

Version: 1.0.0

## Product Summary
- This repository provides project-agnostic governance files for AI-assisted coding, enabling a human to maintain consistent guardrails for an AI coding agent across repositories.
- Primary users are human developers who have an AI coding agent (Copilot, Claude Code, Codex) working in their projects.
- The core user flow is: copy workflow and spec files into a target repository, configure the agent to read them, then run tasks through the defined workflow with human checkpoints.

## Domain Concepts
- **AI workflow**: the step-by-step process defined in `ai-workflow.md` that the agent follows for every task.
- **Project spec**: a factual reference document (`project-spec.md`) describing the target repository's current implementation state, created from `project-spec-template.md`.
- **Validation state**: a local runtime artifact (`.ai-policy/state/validation.status`) tracking whether the current validation run has passed.
- **Policy layer**: the set of shell scripts in `.ai-policy/` that enforce protected-branch and validation-state rules.
- **Skill**: a domain-specific instruction file loaded on demand by the agent when a workflow step requires it.
- **Checkpoint**: a required human-review pause defined in the workflow before a consequential action.

## Scope
- Defines a reusable AI coding workflow (`ai-workflow.md`) with planning, validation, scope-control, failure-analysis, and GitHub handoff rules.
- Provides a project-spec template (`project-spec-template.md`) for documenting implementation truth in any target repository.
- Provides a local policy enforcement layer (`.ai-policy/`) with scripts that enforce protected-branch and validation-state rules.
- Provides git hooks (`.githooks/pre-commit`, `.githooks/pre-push`) that block commits and pushes when policy checks fail.
- Provides agent skills for code-aware planning, failure analysis, issue creation, and test construction, located in two directories: `.agents/skills/` (cross-platform, for VS Code Copilot, Gemini CLI, Codex) and `.claude/skills/` (Claude Code). Both directories contain the same skills.
- Provides agent instruction entry points for VS Code Copilot (`.github/copilot-instructions.md`), Claude Code (`CLAUDE.md`), and Codex (`AGENTS.md`).
- Records observed AI agent failure patterns (`observed-ai-failings.md`) to inform workflow rule changes.
- Provides a lite-monolithic version (`lite-monolithic/ai-workflow.md`) that condenses the workflow into a single self-contained file with no policy layer, skills, or multi-agent entry points.
- Does not contain any runtime application code.
- Does not include a test framework beyond shell-script syntax checks and two enforcement integration tests.

## Important Constraints
- Agent-facing files must stay short enough to preserve context budget.
- `project-spec.md` must stay under 300 lines.
- No work may be done directly on `main` or `master`; the policy layer and git hooks enforce this at commit and push time.
- Validation must pass before commit or push when hooks are installed.
- All facts in `project-spec.md` must reflect implementation truth, not planned architecture.

## Architecture Summary
- This is a documentation-only repository with no runtime application.
- Three layers exist: agent-facing governance files (workflow and spec documents), on-demand skill files loaded at specific workflow steps, and a local policy enforcement layer (scripts and git hooks).
- Primary data flow: human copies files to target repository → agent reads them before each task → agent follows the workflow → human reviews checkpoints.
- No external service dependencies exist at repository runtime; GitHub is used only for issue and PR tracking.

## Key Dependencies
- `bash`: all policy scripts and git hooks are written in bash and validated with `bash -n`.
- `git`: hooks integrate with the git commit and push lifecycle via `core.hooksPath .githooks`.
- `jq`: hook scripts and one enforcement test parse JSON with `jq`.

## Project Structure
- `ai-workflow.md`: canonical workflow steps, validation rules, scope controls, and GitHub handoff rules for the AI agent.
- `ai-workflow-design-decisions/`: maintenance rules and rationale for editing `ai-workflow.md`, split into topic-scoped files.
- `project-spec-template.md`: template for creating `project-spec.md` in a target repository.
- `project-spec-design-decisions.md`: maintenance rules for keeping `project-spec.md` factual and concise.
- `observed-ai-failings.md`: log of concrete AI agent failure patterns observed in real sessions.
- `.agents/skills/`: cross-platform skill definitions (`planning`, `failure-analysis`, `logging-and-observability`, `issue-creation`, `testing`), each self-contained in a `SKILL.md` file. Used by VS Code Copilot, Gemini CLI, and Codex.
- `.claude/skills/`: Claude Code skill definitions (same skills as `.agents/skills/`), each self-contained in a `SKILL.md` file.
- `.github/copilot-instructions.md`: VS Code Copilot agent instructions pointing to `ai-workflow.md` and `project-spec.md`.
- `AGENTS.md`: Codex agent instructions; structure mirrors `.github/copilot-instructions.md`.
- `CLAUDE.md`: Claude Code agent instructions; structure mirrors `.github/copilot-instructions.md`.
- `GEMINI.md`: Gemini CLI agent instructions; structure mirrors `AGENTS.md`.
- `.ai-policy/policy.env`: declares protected branches, validation state file path, and validation command.
- `.ai-policy/scripts/`: shell scripts for running validation, marking pass/fail state, and testing enforcement.
- `.ai-policy/hooks/`: hook logic scripts invoked by `.githooks/`, `.claude/settings.json`, `.codex/hooks.json`, `.gemini/settings.json`, and `.github/hooks/`.
- `.githooks/pre-commit`, `.githooks/pre-push`: git hooks that call `.ai-policy/` scripts to enforce policy.
- `.github/hooks/block-protected-branch.json`: VS Code Copilot PreToolUse hook configuration for protected branch enforcement.
- `.gemini/settings.json`: Gemini CLI settings including BeforeTool hook configuration and tool permission defaults.
- `.vscode/settings.json`: VS Code Copilot tool permission defaults.
- `.codex/config.toml`, `.codex/hooks.json`: Codex-specific agent configuration, permission defaults, and hook definitions.
- `.claude/settings.json`: Claude Code settings including hook configuration and tool permission defaults.
- `lite-monolithic/ai-workflow.md`: single-file AI workflow with planning and failure analysis inlined, no policy layer or skill indirection.
- `lite-monolithic/README.md`: usage instructions for the lite-monolithic version.

## Testing Overview
- Validation runs `bash -n` syntax checks on all shell scripts in `.ai-policy/scripts/`, `.ai-policy/hooks/`, and `.githooks/`.
- Validation also runs four enforcement integration tests: `test-claude-code-enforcement.sh`, `test-codex-enforcement.sh`, `test-vscode-copilot-enforcement.sh`, and `test-gemini-enforcement.sh`.
- No unit test framework exists; there are no automated tests for documentation content.
- Manual verification is the primary check for documentation changes.

## Maintenance Checklist
- Update this file when the project structure, key files, or policy rules change.
- Keep this file aligned with the current codebase, not planned architecture.
- Keep this file concise and under 300 lines.
