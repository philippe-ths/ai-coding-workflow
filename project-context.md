# Project Context

Version: 1.15.0

## Product Summary
- This repository provides project-agnostic governance files for AI-assisted coding, enabling a human to maintain consistent guardrails for an AI coding agent across repositories.
- Primary users are human developers who have an AI coding agent (Copilot, Claude Code, Codex) working in their projects.
- The core user flow is: install the workflow into a target repository with the agent-driven installer (or by pointing an agent at this repo), then run tasks through the defined workflow with human checkpoints.
- The repository also hosts a local, single-developer session-observation tool used to watch the maintainer's own Claude Code usage across repos.

## Domain Concepts
- **AI workflow**: the step-by-step process defined in `ai-workflow.md` that the agent follows for every task.
- **Project context**: a factual reference document (`project-context.md`) describing the target repository's current implementation state, authored using the `aiw-project-context-management` skill.
- **Validation state**: a local runtime artifact (`.ai-policy/state/validation.status`) tracking whether the current validation run has passed.
- **Policy layer**: the set of shell scripts in `.ai-policy/` that enforce protected-branch and validation-state rules.
- **Skill**: a domain-specific instruction file loaded on demand by the agent when a workflow step requires it.
- **Checkpoint**: a required human-review pause defined in the workflow before a consequential action.
- **Install manifest**: the source-of-truth file (`install-manifest.json`) declaring, per profile and tool, which files are product (installed into a target) and which are factory (this repo's own machinery, never installed).
- **Profile**: an install variant, `full` (policy layer, skills, entry point) or `lite` (single self-contained file).
- **Vendored install**: installed governance files recorded in the target's `.gitignore` so they are not committed into the target's own history.
- **Session observation**: the local tooling under `observation/` that reads Claude Code session transcripts and presents descriptive per-session metrics with no statistical verdict.
- **Session Store**: a global JSONL file (`~/.claude/aiw-observation/sessions.jsonl`) holding one metrics row per session, rebuilt from transcripts on demand.
- **Manifest**: a global file written by a SessionStart hook recording each session's `workflow_version` and repo, the only reliable source of the version active during a session.
- **Rating**: a human 1-4 session quality score recorded live by the global `/rate` skill and matched to its session by repo and time.

## Scope
- Defines a reusable AI coding workflow (`ai-workflow.md`) with planning, validation, scope-control, failure-analysis, and GitHub handoff rules.
- Provides a project-context management skill (`aiw-project-context-management`) for authoring and maintaining a repository's `project-context.md`.
- Provides a local policy enforcement layer (`.ai-policy/`) with scripts that enforce protected-branch and validation-state rules.
- Provides git hooks (`.githooks/pre-commit`, `.githooks/pre-push`) that block commits and pushes when policy checks fail.
- Provides agent skills for code-aware planning, ground-truth sourcing, failure analysis, GitHub handoff, issue creation, test construction, verification, performance profiling, security testing, and project-context management, located in two directories: `.agents/skills/` (cross-platform, for VS Code Copilot, Gemini CLI, Codex) and `.claude/skills/` (Claude Code).
- Both skill directories contain the same skills.
- Provides agent instruction entry points for VS Code Copilot (`.github/copilot-instructions.md`), Claude Code (`CLAUDE.md`), Codex (`AGENTS.md`), and Gemini CLI (`GEMINI.md`).
- Provides an agent-driven installer (`scripts/install.sh`) and updater (`scripts/update.sh`) that copy the product file set for a chosen tool and profile into a target repository, vendor them in the target's `.gitignore`, and reconcile removals on update from `CHANGELOG.md`.
- Declares the product/factory boundary in `install-manifest.json`, validated by `scripts/check-manifest.sh` and printed by `make classify`.
- Records observed AI agent failure patterns (`observations/observed-ai-failings.md`) to inform workflow rule changes.
- Provides a lite-monolithic version (`lite-monolithic/ai-workflow.md`) that condenses the workflow into a single self-contained file with no policy layer, skills, or multi-agent entry points.
- Provides a local session-observation tool (`observation/`) that parses Claude Code transcripts into a JSONL Session Store and a self-contained static HTML dashboard.
- The observation tool is descriptive only: it surfaces how metrics move across workflow versions and over time, and never computes a statistical comparison or pass/fail verdict.
- Observation capture (a SessionStart Manifest hook and the `/rate` skill) installs once into the developer's global `~/.claude/` config so it fires in every repo; only the reader and dashboard live in this repo.
- Does not include a unit-test framework; validation covers shell-script syntax, Python `py_compile`, the observation parser regression test, enforcement integration tests, and JSONL fixture validity.

## Important Constraints
- Agent-facing files must stay short enough to preserve context budget.
- `project-context.md` must stay under 300 lines.
- No work may be done directly on `main` or `master`; the policy layer and git hooks enforce this at commit and push time.
- Validation must pass before commit or push when hooks are installed.
- All facts in `project-context.md` must reflect implementation truth, not planned architecture.
- The Session Store records metrics only, never prompt or code content, so pooling sessions from many repos locally needs no redaction.
- `install-manifest.json` must classify every git-tracked file as product, factory, or authored-in-target; `scripts/check-manifest.sh` enforces this in validation.
- Installed governance files are vendored: the installer records them in the target's `.gitignore` and does not commit them to the target's history.
- `CHANGELOG.md` `### Removed` bullets must lead with the removed path so the update path can delete dropped files; `scripts/check-changelog-removals.sh` enforces this (factory-only, not shipped).

## Architecture Summary
- This is primarily a documentation repository; its runtime code is the session-observation tool under `observation/` and the install/update tooling under `scripts/`.
- Four layers exist: agent-facing governance files (workflow and context documents), on-demand skill files loaded at specific workflow steps, a local policy enforcement layer (scripts and git hooks), and the local session-observation tool.
- Primary data flow: the agent-driven installer (`scripts/install.sh`) copies the product files into a target repository, the agent reads them before each task, the agent follows the workflow, the human reviews checkpoints.
- Observation data flow: a SessionStart hook records the Manifest, the `/rate` skill records Ratings, then `observation/collect.py` reads all transcripts under `~/.claude/projects/`, joins the Manifest and Ratings, writes the Session Store, and regenerates a static HTML dashboard.
- Observation runs on demand with a full rebuild each time; nothing runs in the background except the event-driven Manifest hook.
- No external service dependencies exist at repository runtime; GitHub is used only for issue and PR tracking.

## Key Dependencies
- `bash`: all policy scripts, git hooks, and observation capture scripts are written in bash and validated with `bash -n`.
- `git`: hooks integrate with the git commit and push lifecycle via `core.hooksPath .githooks`.
- `jq`: hook scripts and one enforcement test parse JSON with `jq`.
- `python3`: required by the observation tool (`observation/*.py`), the Manifest hook, and `scripts/repo-validation.sh`; the workflow itself does not need it.
- A web browser: opens the generated static HTML dashboard; no server is involved.

## Project Structure
- `ai-workflow.md`: canonical workflow steps, validation rules, scope controls, and GitHub handoff rules for the AI agent; its `Version:` header is the canonical project version.
- `install-manifest.json`: source of truth for the product/factory boundary; lists product files per profile and tool, authored-in-target files, and factory-only files.
- `INSTALL.md`: agent-actionable entry doc for installing or updating the workflow in a target repository.
- `CHANGELOG.md`: Common Changelog record of every version bump; enforced by the pre-push changelog hook; `### Removed` bullets lead with the removed path so the updater can extract them.
- `CONTEXT.md`: glossary of the session-observation domain language.
- `docs/adr/`: architecture decision records; `0001` and `0002` record the move to descriptive observation and global capture.
- `design/`: maintenance documentation for the repository; `design/decisions/` holds concern-scoped rationale files and `design/research/` holds primary-source notes with stable anchor IDs.
- `observations/observed-ai-failings.md`: log of concrete AI agent failure patterns observed in real sessions.
- `observations/workflow-reviews/`: archived periodic review outputs, each named by date.
- `.agents/skills/`: cross-platform skill definitions (`aiw-planning`, `aiw-ground-truth`, `aiw-github`, `aiw-failure-analysis`, `aiw-issue-creation`, `aiw-testing`, `aiw-verification`, `aiw-performance-profiling`, `aiw-security-testing`, `aiw-project-context-management`, `aiw-prompt-smith`), each self-contained in a `SKILL.md` file.
- `.claude/skills/`: Claude Code skill definitions (same skills as `.agents/skills/`), each self-contained in a `SKILL.md` file.
- `.github/copilot-instructions.md`: VS Code Copilot agent instructions pointing to `ai-workflow.md` and `project-context.md`.
- `AGENTS.md`: Codex agent instructions; structure mirrors `.github/copilot-instructions.md`.
- `CLAUDE.md`: Claude Code agent instructions; structure mirrors `.github/copilot-instructions.md`.
- `GEMINI.md`: Gemini CLI agent instructions; structure mirrors `AGENTS.md`.
- `.ai-policy/policy.env`: declares protected branches, validation state file path, and validation command.
- `.ai-policy/scripts/`: shell scripts for running validation, marking pass/fail state, and testing enforcement; `project-validation.sh` is the portable policy-layer check (shell-script syntax plus enforcement tests gated on the agent entry points installed) and invokes `scripts/repo-validation.sh` afterwards when present, warning loudly when it is absent.
- `.ai-policy/hooks/`: hook logic scripts invoked by `.githooks/`, `.claude/settings.json`, `.codex/hooks.json`, `.gemini/settings.json`, and `.github/hooks/`, including `check-changelog.sh` (pre-push, rejects `ai-workflow.md` version bumps without a matching `CHANGELOG.md` entry).
- `.githooks/pre-commit`, `.githooks/pre-push`: git hooks that call `.ai-policy/` scripts to enforce policy.
- `.github/hooks/block-protected-branch.json`: VS Code Copilot PreToolUse hook configuration for protected branch enforcement.
- `.gemini/settings.json`: Gemini CLI settings including BeforeTool hook configuration and tool permission defaults.
- `.vscode/settings.json`: VS Code Copilot tool permission defaults.
- `.codex/config.toml`, `.codex/hooks.json`: Codex-specific agent configuration, permission defaults, and hook definitions.
- `.claude/settings.json`: Claude Code settings including hook configuration and tool permission defaults.
- `lite-monolithic/ai-workflow.md`: single-file AI workflow with planning and failure analysis inlined, no policy layer or skill indirection.
- `lite-monolithic/README.md`: usage instructions for the lite-monolithic version.
- `observation/collect.py`: reads all session transcripts, joins Manifest and Ratings, writes the Session Store, and regenerates the dashboard.
- `observation/parse.py`: the only module that knows the transcript JSONL format; extracts per-session metrics.
- `observation/pricing.py`: model price table and estimated-cost calculation, since transcripts store no cost.
- `observation/dashboard.py`: renders the Session Store into a self-contained static HTML dashboard with client-side filters.
- `observation/test_parse.py`: parser regression test asserting exact values against a checked-in fixture.
- `observation/fixtures/sample-transcript.jsonl`: a real-shaped transcript fixture with chosen values for the parser test.
- `observation/capture/manifest-hook.sh`: defensive SessionStart hook that appends a Manifest row and never blocks a session.
- `observation/capture/record-rating.sh`: appends a 1-4 Rating row, invoked by the `/rate` skill.
- `observation/capture/rate/SKILL.md`: the global `/rate` skill source.
- `observation/install-observation.sh`: installs capture and the `/rate` skill into global `~/.claude/`, honoring `CLAUDE_HOME` for testing.
- `observation/README.md`: setup and usage for the observation tool.
- `Makefile`: `observe` rebuilds the store and opens the dashboard; `observe-test` runs the parser test; `classify` prints the product/factory boundary.
- `scripts/install.sh`: copies the product set for a tool and profile into a target repo, vendors it in the target's `.gitignore`, and installs hooks (full profile); lite copies the single file plus a generated entry.
- `scripts/update.sh`: updates an installed copy by re-copying the current product, auto-detecting tool and profile, and reconciling removals from the source `CHANGELOG.md`.
- `scripts/classify.sh`: prints the product/factory classification read from `install-manifest.json`.
- `scripts/check-manifest.sh`: validates that the manifest classifies every git-tracked file exactly once.
- `scripts/check-changelog-removals.sh`: enforces the leading-path convention on `### Removed` bullets (factory-only).
- `scripts/test-install.sh`, `scripts/test-update.sh`, `scripts/test-changelog-removals.sh`: sandbox tests for the installer, updater, and changelog convention.
- `scripts/repo-validation.sh`: this repo's repo-specific validation; runs shell and Python checks on `observation/`, the parser regression test, JSONL fixture validity, the manifest integrity check, and the install, update, and changelog-removals sandbox tests.

## Testing Overview
- Policy-layer validation (`./.ai-policy/scripts/project-validation.sh`, portable across repos) runs `bash -n` on `.ai-policy/scripts/`, `.ai-policy/hooks/`, and `.githooks/`, then the enforcement test scripts whose matching agent entry point is installed.
- Enforcement test scripts are gated as follows: `test-claude-code-enforcement.sh` requires `.claude/`; `test-codex-enforcement.sh` requires `.codex/`; `test-gemini-enforcement.sh` requires `.gemini/`; `test-vscode-copilot-enforcement.sh` requires `.github/hooks/`; `test-changelog-hook.sh`, `test-pre-push-hook.sh`, and `test-project-validation.sh` always run.
- When `scripts/repo-validation.sh` is absent, `project-validation.sh` warns loudly that only the policy layer ran rather than skipping silently, so a fresh install cannot present a green-but-empty gate; `test-project-validation.sh` regression-tests both the absent (warns, still passes) and present (runs it, no warning) branches.
- Repo-specific validation in `scripts/repo-validation.sh` runs `bash -n` on `observation/*.sh`, `py_compile` on `observation/*.py`, the `observation/test_parse.py` parser regression test, a JSONL validity check on the fixture, the manifest integrity check, and the installer, updater, and changelog-removals sandbox tests.
- No unit test framework exists; there are no automated tests for documentation content or for the generated dashboard's rendering.
- Manual verification is the primary check for documentation changes and for the dashboard's visual behaviour.

## Maintenance Checklist
- Update this file when the project structure, key files, or policy rules change.
- Keep this file aligned with the current codebase, not planned architecture.
- Keep this file concise and under 300 lines.
- When a user-facing file changes, bump the version in `ai-workflow.md` following the guidance in `design/decisions/maintenance.md`.
- When this file changes, bump its own `Version:` header per the `project-context.md` version rule in `design/decisions/maintenance.md`.
- When adding a top-level tracked file, classify it in `install-manifest.json`; validation fails until every tracked file is classified.
