# Project Context

Version: 1.3.0

## Product Summary
- This repository provides project-agnostic governance files for AI-assisted coding, enabling a human to maintain consistent guardrails for an AI coding agent across repositories.
- Primary users are human developers who have an AI coding agent (Copilot, Claude Code, Codex) working in their projects.
- The core user flow is: copy workflow and context files into a target repository, configure the agent to read them, then run tasks through the defined workflow with human checkpoints.

## Domain Concepts
- **AI workflow**: the step-by-step process defined in `ai-workflow.md` that the agent follows for every task.
- **Project context**: a factual reference document (`project-context.md`) describing the target repository's current implementation state, authored using the `aiw-project-context-management` skill.
- **Validation state**: a local runtime artifact (`.ai-policy/state/validation.status`) tracking whether the current validation run has passed.
- **Policy layer**: the set of shell scripts in `.ai-policy/` that enforce protected-branch and validation-state rules.
- **Skill**: a domain-specific instruction file loaded on demand by the agent when a workflow step requires it.
- **Checkpoint**: a required human-review pause defined in the workflow before a consequential action.

## Scope
- Defines a reusable AI coding workflow (`ai-workflow.md`) with planning, validation, scope-control, failure-analysis, and GitHub handoff rules.
- Provides a project-context management skill (`aiw-project-context-management`) for authoring and maintaining a repository's `project-context.md`.
- Provides a calendar-driven periodic review process (`workflow-review.md`) executed outside the per-task workflow; analyses accumulated telemetry and baseline results and produces classified workflow improvement proposals (hook, skill, rule, step, multi).
- Provides a local policy enforcement layer (`.ai-policy/`) with scripts that enforce protected-branch and validation-state rules.
- Provides git hooks (`.githooks/pre-commit`, `.githooks/pre-push`) that block commits and pushes when policy checks fail.
- Provides agent skills for code-aware planning, failure analysis, issue creation, test construction, and project context management, located in two directories: `.agents/skills/` (cross-platform, for VS Code Copilot, Gemini CLI, Codex) and `.claude/skills/` (Claude Code). Both directories contain the same skills.
- Provides agent instruction entry points for VS Code Copilot (`.github/copilot-instructions.md`), Claude Code (`CLAUDE.md`), and Codex (`AGENTS.md`).
- Records observed AI agent failure patterns (`observed-ai-failings.md`) to inform workflow rule changes.
- Provides a lite-monolithic version (`lite-monolithic/ai-workflow.md`) that condenses the workflow into a single self-contained file with no policy layer, skills, or multi-agent entry points.
- Provides an optional local telemetry stack (`telemetry/`) with OTEL Collector, Prometheus, Loki, Grafana, redaction processors, and four pre-provisioned dashboards for evaluating workflow changes from Claude Code session telemetry.
- Provides user-facing documentation (`docs/telemetry-setup.md`, `docs/telemetry-schema.md`) for running the stack and the baseline-harness session JSON contract.
- Provides a baseline task harness (`evals/`, `scripts/run-baseline.sh`, `scripts/compare-versions.py`) that runs frozen coding tasks under any workflow version and writes per-session JSONs matching `docs/telemetry-schema.md`. Ships a host-side `mock` agent for plumbing tests and a `claude-code` agent that runs the Claude Code CLI inside a Docker sandbox.
- Beyond the optional telemetry stack, the repository now ships runtime Python code under `evals/` and `scripts/`.
- Does not include a unit-test framework for that Python code; validation covers shell-script syntax, YAML/JSON syntax, Python `py_compile` on harness and scripts, seven enforcement integration tests, and the baseline-harness's own pytest graders invoked per run.

## Important Constraints
- Agent-facing files must stay short enough to preserve context budget.
- `project-context.md` must stay under 300 lines.
- No work may be done directly on `main` or `master`; the policy layer and git hooks enforce this at commit and push time.
- Validation must pass before commit or push when hooks are installed.
- All facts in `project-context.md` must reflect implementation truth, not planned architecture.

## Architecture Summary
- This is primarily a documentation repository. Runtime components are the optional local telemetry stack under `telemetry/` and the baseline task harness under `evals/` + `scripts/`.
- Five layers exist: agent-facing governance files (workflow and context documents), on-demand skill files loaded at specific workflow steps, a local policy enforcement layer (scripts and git hooks), an optional local telemetry stack for observing workflow effectiveness, and a baseline task harness that produces cross-version reliability numbers (pass^k, McNemar, continuous-metric deltas).
- Primary data flow: human copies files to target repository → agent reads them before each task → agent follows the workflow → human reviews checkpoints.
- Optional telemetry flow (this repo only): Claude Code session → OTEL Collector (localhost:4317/4318) → redaction processors → Prometheus (metrics) + Loki (logs) → Grafana dashboards.
- No external service dependencies exist at repository runtime; GitHub is used only for issue and PR tracking.

## Key Dependencies
- `bash`: all policy scripts and git hooks are written in bash and validated with `bash -n`.
- `git`: hooks integrate with the git commit and push lifecycle via `core.hooksPath .githooks`.
- `jq`: hook scripts and one enforcement test parse JSON with `jq`.
- `docker` (optional): required only for the local telemetry stack in `telemetry/`. Not needed to use the workflow itself.
- `python3` + `pyyaml` (optional): used by `project-validation.sh` to syntax-check telemetry YAML/JSON if present; validation skips the check when absent.
- `python3` (required for the baseline harness): `scripts/run-baseline.sh` creates `evals/.venv` and installs `pytest` and `scipy`. Not needed to use the workflow itself.
- `docker` (required for the baseline harness's `claude-code` agent): launches the Claude Code CLI in an isolated sandbox. The `mock` agent does not need Docker.

## Project Structure
- `ai-workflow.md`: canonical workflow steps, validation rules, scope controls, and GitHub handoff rules for the AI agent. Its `Version:` header is the canonical project version.
- `workflow-review.md`: calendar-driven periodic review process executed outside the per-task workflow. Defines the minimum-data gate, inputs read, analyses run, proposal output format with five classifications (hook, skill, rule, step, multi), disqualifying conditions, and approval workflow.
- `docs/workflow-review-example-2026-04-19.md`: first worked example produced under the periodic review process; demonstrates the gate refusing on quantitative thinness and includes one illustrative qualitative-only proposal.
- `CHANGELOG.md`: Common Changelog record of every version bump; enforced by the pre-push changelog hook.
- `ai-workflow-design-decisions/`: maintenance rules and rationale for editing `ai-workflow.md`, split into topic-scoped files.
- `project-context-design-decisions.md`: maintenance rules for keeping `project-context.md` factual and concise.
- `observed-ai-failings.md`: log of concrete AI agent failure patterns observed in real sessions.
- `.agents/skills/`: cross-platform skill definitions (`aiw-planning`, `aiw-failure-analysis`, `aiw-logging-and-observability`, `aiw-issue-creation`, `aiw-testing`, `aiw-project-context-management`), each self-contained in a `SKILL.md` file. Used by VS Code Copilot, Gemini CLI, and Codex.
- `.claude/skills/`: Claude Code skill definitions (same skills as `.agents/skills/`), each self-contained in a `SKILL.md` file.
- `.github/copilot-instructions.md`: VS Code Copilot agent instructions pointing to `ai-workflow.md` and `project-context.md`.
- `AGENTS.md`: Codex agent instructions; structure mirrors `.github/copilot-instructions.md`.
- `CLAUDE.md`: Claude Code agent instructions; structure mirrors `.github/copilot-instructions.md`.
- `GEMINI.md`: Gemini CLI agent instructions; structure mirrors `AGENTS.md`.
- `.ai-policy/policy.env`: declares protected branches, validation state file path, and validation command.
- `.ai-policy/scripts/`: shell scripts for running validation, marking pass/fail state, testing enforcement, and keeping Claude Code session tags in sync via `update-session-tags.sh`.
- `.ai-policy/hooks/`: hook logic scripts invoked by `.githooks/`, `.claude/settings.json`, `.codex/hooks.json`, `.gemini/settings.json`, and `.github/hooks/`. Includes `check-changelog.sh` (pre-push, rejects `ai-workflow.md` version bumps without a matching `CHANGELOG.md` entry) and `check-session-tags.sh` (pre-commit, rejects drift between `.claude/settings.json`'s `env.OTEL_RESOURCE_ATTRIBUTES` and the current ruleset).
- `.githooks/pre-commit`, `.githooks/pre-push`: git hooks that call `.ai-policy/` scripts to enforce policy.
- `.github/hooks/block-protected-branch.json`: VS Code Copilot PreToolUse hook configuration for protected branch enforcement.
- `.gemini/settings.json`: Gemini CLI settings including BeforeTool hook configuration and tool permission defaults.
- `.vscode/settings.json`: VS Code Copilot tool permission defaults.
- `.codex/config.toml`, `.codex/hooks.json`: Codex-specific agent configuration, permission defaults, and hook definitions.
- `.claude/settings.json`: Claude Code settings including hook configuration and tool permission defaults.
- `lite-monolithic/ai-workflow.md`: single-file AI workflow with planning and failure analysis inlined, no policy layer or skill indirection.
- `lite-monolithic/README.md`: usage instructions for the lite-monolithic version.
- `telemetry/docker-compose.yml`: four-service local stack (OTEL Collector, Prometheus, Loki, Grafana) for receiving and visualising Claude Code session telemetry.
- `telemetry/otel-collector-config.yaml`: OTLP receivers on `:4317`/`:4318`, redaction processors (identity-attribute strip, body regex scrub, attribute truncation), and exporters to Prometheus and Loki.
- `telemetry/prometheus/prometheus.yml`, `telemetry/loki/loki-config.yaml`: backend configs with 30-day retention.
- `telemetry/grafana/provisioning/`: auto-wired datasources and dashboard provider.
- `telemetry/grafana/dashboards/`: four pre-built dashboards — `session-overview.json`, `tool-usage.json`, `fix-cycles.json` (placeholder until Sub-issue D), `version-comparison.json`.
- `telemetry/up.sh`, `telemetry/down.sh`: convenience wrappers around `docker compose`.
- `telemetry/.gitignore`: blocks captured data from being committed.
- `docs/telemetry-setup.md`: maintainer-facing setup, redaction, and troubleshooting guide for the telemetry stack.
- `docs/telemetry-schema.md`: baseline-harness per-session JSON contract (v0.2, locked by #112).
- `evals/harness/`: Python baseline harness — runner, JSON writer, workflow-version / ruleset-hash reader, pytest grader, `mock` and `claude-code` agents, plus `Dockerfile` + `compose.yaml` for the sandbox used by the `claude-code` agent.
- `evals/tasks/<task_id>/`: frozen baseline tasks. Each has `spec.md` (prompt + acceptance criteria), `starter/` (code the agent sees), `grader/` (hidden pytest applied after the agent completes), and `solution/` (reference solution used only by the `mock` agent).
- `evals/requirements.txt`: Python dependencies for the harness (`pytest`, `scipy`).
- `scripts/run-baseline.sh`: creates `evals/.venv`, runs `N` tasks × `k` repeats, writes results under `telemetry/data/baseline/<version>/<ruleset_hash>/<task>/<run>.json`.
- `scripts/compare-versions.py`: reads two versions' results and prints per-task pass^k, aggregate pass^k, McNemar's test on paired outcomes, and mean/median deltas on duration, cost, tokens, and fix cycles.

## Testing Overview
- Validation runs `bash -n` syntax checks on all shell scripts in `.ai-policy/scripts/`, `.ai-policy/hooks/`, `.githooks/`, and `telemetry/*.sh`.
- Validation runs YAML syntax checks on telemetry configs when `python3` + `pyyaml` are present, JSON syntax checks on Grafana dashboards, and `docker compose config -q` in `telemetry/` when Docker is installed.
- Validation also runs seven enforcement integration tests: `test-claude-code-enforcement.sh`, `test-codex-enforcement.sh`, `test-vscode-copilot-enforcement.sh`, `test-gemini-enforcement.sh`, `test-changelog-hook.sh`, `test-session-tags-hook.sh`, and `test-pre-push-hook.sh`.
- No unit test framework exists; there are no automated tests for documentation content or Grafana dashboard correctness.
- Manual verification is the primary check for documentation changes and telemetry dashboard behaviour.

## Maintenance Checklist
- Update this file when the project structure, key files, or policy rules change.
- Keep this file aligned with the current codebase, not planned architecture.
- Keep this file concise and under 300 lines.
- When a user-facing file changes, bump the version in `ai-workflow.md` following the guidance in `ai-workflow-design-decisions/context-budget-and-maintenance.md`.
