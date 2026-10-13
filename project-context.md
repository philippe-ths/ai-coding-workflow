# Project Context

Version: 2.2.0

## Product Summary
- This repository is a project-agnostic AI coding workflow: rules, skills, and a policy layer that an installer copies into a target repository for Claude Code, Codex, or VS Code Copilot.
- Its users are developers who direct an AI coding agent in their own repositories.
- It also holds a local tool, under `observation/`, that reads the maintainer's own Claude Code sessions across repositories.

## Constraints
- No work happens on `main` or `master`: git hooks and agent hooks block commits and pushes there.
- A push needs a validation pass recorded for the current working tree, so any change to tracked or untracked, non-ignored content after a run voids the pass.
- A commit needs no validation pass: `REQUIRE_VALIDATION_BEFORE_COMMIT` is `false`, so pre-commit only refuses protected branches.
- A push is refused from a dirty tree, and for a ref whose tip is not `HEAD`, since only `HEAD` carries the content validation read.
- The agent cannot merge or approve a pull request; hooks block both on the shell and MCP routes.
- Opening or editing a pull request is blocked unless the body carries a verification justification and its unverified-surface section is more than a bare "none".
- That body must also record an `aiw-prompt-smith` pass when the branch changed agent-facing prose: skills, agent files, `ai-workflow.md`, the entry points, or a file an entry point pulls in with an `@` line, which includes this file.
- The pull request hook must read the body before the command runs, so it blocks a body file path built from a shell variable and a body file the same command creates.
- A version bump in `ai-workflow.md` needs a matching `CHANGELOG.md` entry; the pre-push hook rejects it otherwise.
- `### Removed` bullets in `CHANGELOG.md` lead with the removed path, because the updater deletes files from them.
- Every tracked file is classified in `install-manifest.json` as product, factory, or authored-in-target, and validation fails until it is.
- Product files install into targets and factory files never leave this repository.
- Product prose (skills, `ai-workflow.md`, the entry points) may not name a factory-only path; a shipped script may, only on a line marked `factory-path-ok`.
- `.claude/skills/` and `.agents/skills/` carry the same skills with identical content.
- Each skill's `name:` matches its directory, and its description is one line of at most 600 bytes.
- `README.md` names every skill.
- This file stays at or under 2000 tokens and `north-star.md` at or under 400, counted as bytes/4.
- `CLAUDE.md`, `AGENTS.md`, and `.github/copilot-instructions.md` each reference `ai-workflow.md` and `project-context.md` and carry no rules of their own.
- A change that alters agent behaviour in a target bumps the `ai-workflow.md` version, as `design/decisions/maintenance.md` sets out; this file carries its own version.
- The cost of the checks is reported and never gated on.
- The Session Store records metrics only, never prompt or code content.
- `observation/uninstall-observation.sh` and `upkeep/uninstall-upkeep.sh` each reverse what their install script adds outside this repository, keeping recorded data unless told otherwise.

## Build and Validate
- `./.ai-policy/scripts/run-validation.sh` runs validation and records the result the commit and push gate reads; it takes about four minutes.
- Validation runs `bash -n` on the policy layer, every executable `.ai-policy/scripts/test-*.sh` (found by glob, so a test without the executable bit never runs), then `scripts/repo-validation.sh`.
- `scripts/repo-validation.sh` lists its checks by name and skips any that is not executable, so a new factory test under `scripts/` runs only once it is added there and made executable.
- `scripts/check-prose-integrity.sh` enforces the prose constraints above, and also that every skill listing the done gate names the same members as `ai-workflow.md` and that a skill claiming a Task Flow step number matches it.
- It is structural only: it cannot tell whether two passages contradict.
- Shipped hooks and policy scripts use only `bash`, `git`, and `jq`, since a target may have no `python3`; `python3` is needed by `observation/`, `.ai-policy/jev/`, and this repository's validation.
- `core.hooksPath` must be `.githooks`, set by `./.ai-policy/scripts/install-hooks.sh`.
- `.ai-policy/jev/ask.py` needs a TypeSafe key and exits 3 when the key or service is unavailable.
- `make classify` prints the product and factory boundary.
- `scripts/probe-loop-rule.sh` A/B-tests the small-loop rule with headless agents and spends model quota, so it is never part of validation; re-run it when that rule, or one beside it, changes.
- Nothing tests documentation meaning, the dashboard's rendering, or the scripts under `field-notes/`.

## Domain Terms
- **Target**: a repository the workflow is installed into.
- **Seeded file**: a product file shipped once and then owned by the target; `.ai-policy/policy.env` is the only one.
- **Validation state**: `.ai-policy/state/validation.status`, the policy layer's record of a validation run, unrelated to the `aiw-validation` skill.
- **Manifest** in `observation/` means the per-session record of the workflow version, not `install-manifest.json`.
- **Session Store**: `~/.claude/aiw-observation/sessions.jsonl`, one metrics row per session, rebuilt on demand.

## Maintenance
- Update this file when an enforced rule, a contract, or how the repository builds and validates changes.
- When this file changes, bump its own `Version:` header per `design/decisions/maintenance.md`.
