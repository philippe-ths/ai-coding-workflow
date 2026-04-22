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

Tipping points are a judgement call. They come from real-world usage in other repositories — observing where agents actually fail, recording those patterns, and learning which new methods work. The `observations/observed-ai-failings.md` file is where those lessons accumulate.

## History

1. **Single workflow file.** The project started as one document — `ai-workflow.md` — that told the agent what to do: confirm the task, plan, implement, validate, get approval. No enforcement, no tooling.
2. **Failures drove new rules.** Real-world usage across multiple repos and agents surfaced repeated failures: agents skipping branches, bypassing checkpoints, running validation in parallel, pushing without approval. Each pattern was recorded in `observations/observed-ai-failings.md` and addressed with a targeted workflow rule.
3. **Deterministic enforcement.** Workflow rules alone were not enough — agents ignored them under momentum. The `.ai-policy/` layer and `.githooks/` were added to block protected-branch writes and require passed validation before commit or push, without relying on the agent to comply.
4. **Agent-specific enforcement.** Git hooks only cover the shell path. Agents that use MCP connectors bypass hooks entirely. Enforcement was extended to Claude Code (PreToolUse hooks) and Codex (disabled_tools + PreToolUse hooks) to cover both execution paths.
5. **On-demand skills.** The monolithic workflow file grew too large for agent context budgets. Planning and failure analysis were split into standalone skill files loaded only when the workflow step requires them.
6. **Current: global vs on-demand rules.** Finding the right boundary between rules that must always be loaded and rules that can be deferred to skills.

## Repository Contents

### Agent-facing files

- `ai-workflow.md` — canonical workflow for AI-assisted coding tasks, including planning, checkpoints, validation, failure analysis, and GitHub handoff rules.
- `project-context.md` — factual reference for this repository's implementation state, authored using the `aiw-project-context-management` skill.
- `lite-monolithic/` — single-file version of the workflow with planning and failure analysis inlined, no policy layer, no skills, no multi-agent entry points. See `lite-monolithic/README.md`.

### Agent instruction entry points

- `CLAUDE.md` — Claude Code agent instructions.
- `AGENTS.md` — Codex agent instructions.
- `GEMINI.md` — Gemini CLI agent instructions.
- `.github/copilot-instructions.md` — VS Code Copilot agent instructions.

### Skills

- `.agents/skills/` — cross-platform skill definitions (`aiw-planning`, `aiw-failure-analysis`, `aiw-logging-and-observability`, `aiw-issue-creation`, `aiw-testing`). Used by VS Code Copilot, Gemini CLI, and Codex.
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

- `design/` — concern-scoped design decisions and primary-source research. See `design/README.md` for a file index.
- `observations/observed-ai-failings.md` — log of concrete failure patterns observed in real AI-agent sessions.
- `observations/workflow-reviews/` — archived periodic review outputs. The review process is defined in `design/decisions/evaluation.md`.

## Installation by Tool

Copy the relevant files into your target repository. Each agent needs its own instruction entry point, the shared workflow file, and the policy enforcement layer. `project-context.md` is not copied — it is authored in the target repository by invoking the `aiw-project-context-management` skill.

### Claude Code

```
CLAUDE.md
.claude/
.ai-policy/
.githooks/
ai-workflow.md
```

### VS Code Copilot

```
.github/copilot-instructions.md
.agents/skills/
.vscode/
.ai-policy/
.githooks/
ai-workflow.md
```

### Codex

```
AGENTS.md
.agents/skills/
.codex/
.ai-policy/
.githooks/
ai-workflow.md
```

### Gemini CLI

```
GEMINI.md
.agents/skills/
.gemini/
.ai-policy/
.githooks/
ai-workflow.md
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

The shipped validator (`./.ai-policy/scripts/project-validation.sh`) checks only the policy layer itself: shell-script syntax in `.ai-policy/` and `.githooks/`, plus the enforcement tests that match the agent entry points installed in your repo (tests for agents you did not install are skipped).

To add repo-specific checks (tests, linters, type checks, etc.) that run as part of the same validation, create an executable `./scripts/repo-validation.sh` at the root of your repo. The shipped validator invokes it automatically when present. The file is not part of the shipped policy layer, so each repo owns its own.

### Enable session telemetry (Claude Code)

Session telemetry is a standard part of the Claude Code install. From a Claude Code session started in the target repository, invoke the `aiw-telemetry-setup` skill:

> "use the aiw-telemetry-setup skill to start recording telemetry here"

The skill is the single user-facing action required to turn on telemetry. It auto-detects the environment (collector reachability, local stack readiness, `direnv` presence, terminal vs IDE launch context, and any existing configuration), catches inherited identity from files copied in from other repositories, and proposes one consolidated set of file changes. After a single confirmation, it writes the configuration and verifies end-to-end round-trip for every signal the shipped Grafana dashboards consume — logs via Loki and metrics via Prometheus — by emitting synthetic records carrying fresh UUIDs and re-querying each backend. It reports SUCCESS or FAIL with the specific phase that failed and leaves no partial state on failure. It never enables telemetry as a default side effect.

Identity (the `workflow_repo` tag and friends) lives in a gitignored `.envrc`, never in any tracked file, so copying this repo's files into a target repository cannot silently propagate the wrong identity. The local stack itself lives in this repo's `telemetry/` — see [Session Telemetry (this repo)](#session-telemetry-this-repo) for the stack and reference material.

## Session Telemetry (this repo)

This section describes how telemetry works in the `ai-coding-workflow` repository itself. In downstream target repositories, the `aiw-telemetry-setup` skill owns this setup end-to-end — the notes below are reference material for maintainers of this repository.

Every Claude Code session started in this repository emits OTEL events tagged with the current workflow version, the repo identifier, and an 8-character ruleset hash computed from the rule files. The tag string and the enablement variables both live in a gitignored `.envrc`. No tracked file carries telemetry identity.

To enable telemetry locally in this repository, copy the example direnv config and allow it:

```bash
cp .envrc.example .envrc
direnv allow
```

The variables exported are:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_RESOURCE_ATTRIBUTES="workflow_repo=ai-coding-workflow"
```

`OTEL_EXPORTER_OTLP_PROTOCOL` must be set explicitly; Claude Code's OTEL SDK does not infer it from the endpoint and fails init without it. Use `grpc` with port 4317, or `http/protobuf` with port 4318.

Both `OTEL_LOGS_EXPORTER=otlp` and `OTEL_METRICS_EXPORTER=otlp` are required: the shipped Grafana dashboards read both signals. Without one, the dashboards that consume that signal are empty.

`OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative` is also required. Claude Code defaults to delta temporality, but the shipped Prometheus pipeline forwards via remote-write, which expects cumulative. Without this override metrics fail silently — logs continue to flow to Loki, but Prometheus-backed dashboards stay empty.

To keep the full tag string (with `workflow_version` and `ruleset_hash`) in sync with the current rule files in this repo, run:

```bash
./.ai-policy/scripts/update-session-tags.sh
```

This inserts or updates a managed block in `.envrc` delimited by sentinels. It only runs in the `ai-coding-workflow` repository itself; downstream repositories are owned by the skill.

Caveats:

- Some downstream collectors require `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`.
- Claude Code's `-p` one-shot mode may not flush telemetry reliably before exit; use an interactive session to verify emission.
- After bumping the `Version:` header in `ai-workflow.md` or editing any rule file, re-run `update-session-tags.sh` to refresh the managed block.

### Local storage and dashboards

The `telemetry/` directory ships a local OpenTelemetry Collector + Prometheus + Loki + Grafana stack with pre-provisioned dashboards for session overview, tool usage, fix cycles, and cross-version comparison. The Collector applies redaction rules (email/path/API-key scrubbing, identity-attribute stripping) before anything reaches storage, so screenshots and backups stay safe.

```bash
./telemetry/up.sh          # docker compose up -d
./telemetry/down.sh        # stop
./telemetry/down.sh -v     # stop and wipe captured data
```

Grafana is at <http://localhost:3000>. See [`docs/telemetry-setup.md`](docs/telemetry-setup.md) for the full setup, redaction rules, and troubleshooting. See [`docs/telemetry-schema.md`](docs/telemetry-schema.md) for the baseline-harness session JSON contract.

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
