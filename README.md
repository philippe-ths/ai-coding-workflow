# AI Coding Workflow

Project-agnostic workflow and maintenance documents for AI-assisted coding.

AI coding agents routinely skip validation, expand scope beyond what was approved, and ignore human checkpoints. This repository provides a small set of governance files that prevent those failures by giving the agent an explicit workflow with enforced rules and required human approvals.

The workflow is written for the agent. The design decision files are written for the human maintainer.

The workflow assumes GitHub for issue tracking and branching. It is designed as a tightly coupled human-AI collaboration where each side has defined responsibilities — the human scopes work, reviews plans, and approves actions; the agent plans, implements, and validates. Future versions will support more configurable and automated modes.

**Prerequisites:** bash, git.

## Approach

This project is built in layers, simple to complex. Each layer is designed to deliver the maximum gain for the minimum effort and maintenance. Staying with a layer long enough to learn its limitations is the point — a new layer is only added when the current one hits a tipping point.

The first layer was a single monolithic workflow file — one document that told the agent what to do. That worked until the workflow grew complex enough that it needed to be split into on-demand context (skills) and deterministic blockers (policy hooks) that enforce rules without relying on the agent to follow them.

The current focus is finding the right split between always-on global rules and on-demand rules that are loaded only when relevant. After that: formally defined rules, and eventually multi-agent coordination.

Tipping points are a judgement call. They come from real-world usage in other repositories — observing where agents actually fail, recording those patterns, and learning which new methods work. The `observed-ai-failings.md` file is where those lessons accumulate.

## History

1. **Single workflow file.** The project started as one document — `ai-workflow.md` — that told the agent what to do: confirm the task, plan, implement, validate, get approval. No enforcement, no tooling.
2. **Failures drove new rules.** Real-world usage across multiple repos and agents surfaced repeated failures: agents skipping branches, bypassing checkpoints, running validation in parallel, pushing without approval. Each pattern was recorded in `observed-ai-failings.md` and addressed with a targeted workflow rule.
3. **Deterministic enforcement.** Workflow rules alone were not enough — agents ignored them under momentum. The `.ai-policy/` layer and `.githooks/` were added to block protected-branch writes and require passed validation before commit or push, without relying on the agent to comply.
4. **Agent-specific enforcement.** Git hooks only cover the shell path. Agents that use MCP connectors bypass hooks entirely. Enforcement was extended to Claude Code (PreToolUse hooks) and Codex (disabled_tools + PreToolUse hooks) to cover both execution paths.
5. **On-demand skills.** The monolithic workflow file grew too large for agent context budgets. Planning and failure analysis were split into standalone skill files loaded only when the workflow step requires them.
6. **Current: global vs on-demand rules.** Finding the right boundary between rules that must always be loaded and rules that can be deferred to skills.

## Repository Contents

### Agent-facing files

- `ai-workflow.md` — canonical workflow for AI-assisted coding tasks, including planning, checkpoints, validation, failure analysis, and GitHub handoff rules.
- `project-spec.md` — factual reference for this repository's implementation state, authored using the `project-spec-management` skill.
- `lite-monolithic/` — single-file version of the workflow with planning and failure analysis inlined, no policy layer, no skills, no multi-agent entry points. See `lite-monolithic/README.md`.

### Agent instruction entry points

- `CLAUDE.md` — Claude Code agent instructions.
- `AGENTS.md` — Codex agent instructions.
- `GEMINI.md` — Gemini CLI agent instructions.
- `.github/copilot-instructions.md` — VS Code Copilot agent instructions.

### Skills

- `.agents/skills/` — cross-platform skill definitions (`planning`, `failure-analysis`, `logging-and-observability`, `issue-creation`, `testing`). Used by VS Code Copilot, Gemini CLI, and Codex.
- `.claude/skills/` — Claude Code skill definitions (same skills as `.agents/skills/`).

### Policy enforcement

- `.ai-policy/` — shell scripts that enforce protected-branch and validation-state rules.
- `.ai-policy/scripts/test-claude-code-enforcement.sh` — enforcement integration tests for Claude Code.
- `.ai-policy/scripts/test-codex-enforcement.sh` — enforcement integration tests for Codex.
- `.githooks/pre-commit`, `.githooks/pre-push` — git hooks that call `.ai-policy/` scripts.
- `.claude/settings.json` — Claude Code hook configuration and tool permission defaults.
- `.codex/config.toml`, `.codex/hooks.json` — Codex agent configuration, permission defaults, and hook definitions.
- `.gemini/settings.json` — Gemini CLI hook configuration and tool permission defaults.
- `.vscode/settings.json` — VS Code Copilot tool permission defaults.

### Maintenance documents

- `ai-workflow-design-decisions/` — scoped maintenance rules and rationale for editing `ai-workflow.md`.
- `project-spec-design-decisions.md` — maintenance rules for keeping `project-spec.md` factual and concise.
- `observed-ai-failings.md` — log of concrete failure patterns observed in real AI-agent sessions.

## Installation by Tool

Copy the relevant files into your target repository. Each agent needs its own instruction entry point, the shared workflow and spec files, and the policy enforcement layer.

### Claude Code

```
CLAUDE.md
.claude/
.ai-policy/
.githooks/
ai-workflow.md
project-spec.md          # author via the project-spec-management skill
```

### VS Code Copilot

```
.github/copilot-instructions.md
.agents/skills/
.vscode/
.ai-policy/
.githooks/
ai-workflow.md
project-spec.md          # author via the project-spec-management skill
```

### Codex

```
AGENTS.md
.agents/skills/
.codex/
.ai-policy/
.githooks/
ai-workflow.md
project-spec.md          # author via the project-spec-management skill
```

### Gemini CLI

```
GEMINI.md
.agents/skills/
.gemini/
.ai-policy/
.githooks/
ai-workflow.md
project-spec.md          # author via the project-spec-management skill
```

After copying, add the governance files and folders to the target repository's `.gitignore` if they should not be committed there.

### Post-install setup

Install the git hooks:

```bash
./.ai-policy/scripts/install-hooks.sh
```

Run validation:

```bash
./.ai-policy/scripts/run-validation.sh
```

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
