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

- `ai-workflow-design-decisions/` — scoped maintenance rules and rationale for editing `ai-workflow.md`.
- `project-context-design-decisions.md` — maintenance rules for keeping `project-context.md` factual and concise.
- `observed-ai-failings.md` — log of concrete failure patterns observed in real AI-agent sessions.
- `workflow-review.md` — calendar-driven periodic review process: defines how an agent analyses accumulated telemetry plus baseline results to produce classified workflow improvement proposals. Runs outside the per-task workflow. See `docs/workflow-review-example-2026-04-19.md` for the first worked example.

## Installation by Tool

Copy the relevant files into your target repository. Each agent needs its own instruction entry point, the shared workflow and context files, and the policy enforcement layer.

### Claude Code

```
CLAUDE.md
.claude/
.ai-policy/
.githooks/
ai-workflow.md
project-context.md       # author via the project-context-management skill
```

### VS Code Copilot

```
.github/copilot-instructions.md
.agents/skills/
.vscode/
.ai-policy/
.githooks/
ai-workflow.md
project-context.md       # author via the project-context-management skill
```

### Codex

```
AGENTS.md
.agents/skills/
.codex/
.ai-policy/
.githooks/
ai-workflow.md
project-context.md       # author via the project-context-management skill
```

### Gemini CLI

```
GEMINI.md
.agents/skills/
.gemini/
.ai-policy/
.githooks/
ai-workflow.md
project-context.md       # author via the project-context-management skill
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

### Optional: enable session telemetry (Claude Code only)

To start recording Claude Code session data from the target repository into the local stack shipped in this repo, invoke the `aiw-telemetry-setup` skill from a Claude Code session in the target repo, for example:

> "use the aiw-telemetry-setup skill to start recording telemetry here"

The skill auto-detects the environment (collector reachability, `direnv` presence, terminal vs IDE launch context, existing configuration), proposes one consolidated set of file changes, and — after a single confirmation — writes the configuration and verifies round-trip by sending a synthetic OTLP record carrying a fresh UUID and re-querying it from Loki. It reports PASS or FAIL with the specific phase that failed and leaves no partial state on failure. It never enables telemetry as a default side effect. The local stack itself lives in this repo's `telemetry/` — see [Session Telemetry](#session-telemetry-claude-code) below.

## Session Telemetry (Claude Code)

Every Claude Code session started in this repository emits OTEL events tagged with the current workflow version and an 8-character ruleset hash. The tag fragment lives in `.claude/settings.json`'s `env.OTEL_RESOURCE_ATTRIBUTES` block and is kept in sync with the rule files by `.ai-policy/scripts/update-session-tags.sh`. A pre-commit check blocks commits when the fragment drifts.

The repository file declares **what the tags mean**. The maintainer's shell declares **whether telemetry is enabled and where it goes**. The three enablement variables are intentionally not committed, so cloning the repo does not start emitting telemetry.

To enable telemetry locally, copy the example direnv config and allow it:

```bash
cp .envrc.example .envrc
direnv allow
```

The three exported variables are:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

`OTEL_EXPORTER_OTLP_PROTOCOL` must be set explicitly; Claude Code's OTEL SDK does not infer it from the endpoint and fails init without it. Use `grpc` with port 4317, or `http/protobuf` with port 4318.

`OTEL_LOGS_EXPORTER=otlp` is required for event logs (`user_prompt`, `tool_result`, `api_request`) to reach the collector. Without it, only metrics flow.

`.envrc` is gitignored so these values stay on your machine. You can also export them in `~/.zshrc` or the current shell instead of using direnv.

Caveats:

- Some downstream collectors require `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`.
- Claude Code's `-p` one-shot mode may not flush telemetry reliably before exit; use an interactive session to verify emission.
- After bumping the `Version:` header in `ai-workflow.md` or editing any rule file, run `./.ai-policy/scripts/update-session-tags.sh` to refresh the tag fragment.

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
