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
- `project-checks.md` — what this repository is worth checking at session start and what normal looks like for each check, maintained by the `aiw-init` skill.
- `lite-monolithic/` — single-file version of the workflow with planning and failure analysis inlined, no policy layer, no skills, no multi-agent entry points. See `lite-monolithic/README.md`.

### Agent instruction entry points

- `CLAUDE.md` — Claude Code agent instructions.
- `AGENTS.md` — Codex agent instructions.
- `GEMINI.md` — Gemini CLI agent instructions.
- `.github/copilot-instructions.md` — VS Code Copilot agent instructions.

### Skills

- `.agents/skills/` — cross-platform skill definitions (`aiw-init`, `aiw-planning`, `aiw-ground-truth`, `aiw-github`, `aiw-testing`, `aiw-verification`, `aiw-failure-analysis`, `aiw-issue-creation`, `aiw-performance-profiling`, `aiw-security-testing`, `aiw-project-context-management`). Used by VS Code Copilot, Gemini CLI, and Codex.
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
- `observations/workflow-reviews/` — archived outputs from earlier periodic workflow reviews.

## Product vs Factory

This repository is two things at once: the **product** (the workflow files that install into a target repository) and the **factory** (this repo's own machinery for developing, validating, and observing the workflow). Because the repo runs its own workflow, the product files live at the root alongside the factory files rather than in a separate directory.

`install-manifest.json` is the single source of truth for that boundary. It declares, per profile and per tool, which files are product, which are authored fresh in each target, and which are factory-only and must never be copied. `scripts/check-manifest.sh` (run in validation) guarantees every git-tracked file is classified, so nothing can drift out of the boundary unnoticed.

To see the current classification, read the manifest or run:

```bash
make classify
```

## Installation

Point an AI coding agent at this repository — a local path or its URL — and say "install the AI workflow" (or "upgrade the AI workflow"). The agent follows [`INSTALL.md`](INSTALL.md), which drives the installer: it asks which tool (`claude`, `codex`, `gemini`, `copilot`) and profile (`full` or `lite`), copies the right files, records them in the target's `.gitignore`, and installs the git hooks. No hand-copying.

To run it directly instead:

```bash
# fresh install
scripts/install.sh --target <target-repo> --tool claude --profile full

# update an installed copy (auto-detects the installed tool and profile)
scripts/update.sh --target <target-repo>
```

Which files each tool and profile receives is defined in `install-manifest.json` (run `make classify` to print it); see [Product vs Factory](#product-vs-factory). The installer copies only product files. `project-context.md` is not copied — author it in the target with the `aiw-project-context-management` skill so it describes the target repo. `project-checks.md` is not copied either; the `aiw-init` skill scaffolds it from the target on first run.

Governance files are **vendored**: the installer adds them to the target's `.gitignore` so they are not committed into the target's history. The full profile also wires the git hooks (`core.hooksPath`) automatically.

### Wiring in your project's own checks

After installing, run validation in the target:

```bash
./.ai-policy/scripts/run-validation.sh
```

The shipped validator (`./.ai-policy/scripts/project-validation.sh`) checks only the policy layer itself: shell-script syntax in `.ai-policy/` and `.githooks/`, plus the enforcement tests that match the agent entry points installed in your repo (tests for agents you did not install are skipped).

**Wire in your project's own checks — required for the gate to mean anything.** Out of the box the validator runs *none* of your project's tests, linters, or type checks, so a "passed" result only attests to the policy layer. Until you wire your own checks in, every run prints a `WARNING` saying exactly this, so a fresh install can never present a silently-empty green gate.

To close that gap, create an executable `./scripts/repo-validation.sh` at the root of your repo and have it run your tests, linters, and type checks. The shipped validator invokes it automatically when present (and the warning disappears once it is). The file is not part of the shipped policy layer, so each repo owns its own; see this repo's `scripts/repo-validation.sh` for a worked example.

## Session Observation (this repo)

This repository hosts a local, single-developer tool for observing your own Claude Code usage across all your repos. It is descriptive only: it shows how metrics move over time and across workflow versions and leaves the judgement to you, deliberately replacing an earlier statistical telemetry-and-evaluation stack. See [`docs/adr/0001`](docs/adr/0001-descriptive-session-observation-over-statistical-comparison.md) for why, and [`observation/README.md`](observation/README.md) for details.

Install capture once into your global Claude config (a SessionStart hook plus a `/rate` skill). Requires `python3`:

```bash
./observation/install-observation.sh
```

Then work normally — capture is automatic in every repo, with nothing to remember. Optionally record a quality rating during or after any session:

```
/rate 3        # 1 bad, 2 fine, 3 good, 4 excellent
```

When you want to look, rebuild the store and open the dashboard from this repo:

```bash
make observe
```

This reads every transcript already on disk under `~/.claude/projects/`, writes a JSONL Session Store and a self-contained `dashboard.html` under `~/.claude/aiw-observation/`, and opens it. No Docker, no server, nothing running in the background. The store holds metrics only — token usage, estimated cost, tool calls, skill activations, session length, user turns, and your rating — never prompt or code content.

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
