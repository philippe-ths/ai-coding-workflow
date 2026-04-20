# Enforcement Layers

Covers the design decisions behind the `.ai-policy/` deterministic enforcement layer and the `.githooks/` git hooks.

The canonical rule for where in `ai-workflow.md` a deterministic boundary should be mentioned is in `design/decisions/rule-placement.md` under **Deterministic policy placement**.

## Deterministic Policy System (.ai-policy/)

### Why deterministic enforcement exists

The workflow file instructs the agent, but instruction compliance degrades as context grows and task complexity increases.
Bright-line mechanical rules (do not commit on a protected branch, do not commit without passing validation) are too important to rely on instruction-following alone.
The `.ai-policy/` directory moves these rules into deterministic enforcement: shell scripts that block the action at the Git level regardless of whether the agent remembered the rule.

This follows the dual-form placement rule in `design/decisions/rule-placement.md` under **One canonical location per rule**.
The advisory form helps the agent plan correctly; the deterministic form catches it when it does not.

### Why policy.env exists

`policy.env` centralises configuration for the policy system in one file.
Protected branch names, validation toggle flags, state file paths, and the validation command are all defined here.
This avoids scattering configuration across multiple scripts and makes it easy for a human to see or change the policy in one place.
Scripts source this file rather than hardcoding values.

### Protected branch enforcement

`check-protected-branch.sh` blocks commits and pushes to branches listed in `PROTECTED_BRANCHES`.
This enforces the workflow rule "Do not work directly on `main`" at the Git level.
The agent may forget or rationalise working on main; the hook will not.

### Validation state tracking

The validation system uses a simple state file (`validation.status`) with three states: `running`, `passed`, `failed`.

`run-validation.sh` orchestrates the flow: it sets the state to `running`, runs the configured validation command, and sets the state to `passed` or `failed` based on the result.
The `running` state plus a trap on exit ensures that if the script is interrupted or crashes, the state reverts to `failed` rather than remaining `passed` from a stale run.

`check-validation.sh` reads the state file and blocks the Git action unless the state is `passed`.
This enforces the workflow rule that validation must pass before commit or push.

`mark-validation-pass.sh` and `mark-validation-fail.sh` exist as manual overrides.
They allow the human to set validation state directly when the automated flow is not appropriate (e.g. the project has no tests yet, or a known-failing test needs to be bypassed for a specific commit).
These are escape hatches, not normal workflow paths.

### project-validation.sh

`project-validation.sh` is the validation command that `run-validation.sh` invokes.
In this repository it runs `bash -n` (syntax check) on all scripts in `.ai-policy/scripts/` and `.githooks/`.
In an adopting project, this file would be replaced with the project's actual test and build commands.
The indirection through `VALIDATION_COMMAND` in `policy.env` means the validation system works without modifying any script other than `project-validation.sh` (or changing the command path in `policy.env`).

### current-branch.sh

`current-branch.sh` is a one-line helper that returns the current branch name.
It exists as a separate script so that `check-protected-branch.sh` does not embed Git plumbing directly, keeping each script focused on a single concern.

### install-hooks.sh

`install-hooks.sh` sets `core.hooksPath` to `.githooks` and makes all scripts executable.
This is a one-time setup step per clone.
The workflow references it as a recovery step: if hooks are not active, run this script.
Using `core.hooksPath` instead of copying hooks into `.git/hooks/` means the hooks are version-controlled and shared across clones.

## Git Hooks (.githooks/)

### Why hooks are in .githooks/ not .git/hooks/

`.git/hooks/` is local and not version-controlled.
`.githooks/` is committed to the repository, which means every clone gets the same enforcement.
`install-hooks.sh` configures Git to use this directory via `core.hooksPath`.

### pre-commit hook

The pre-commit hook runs two checks in order:
1. Protected branch check: blocks the commit if on a protected branch.
2. Validation check (if enabled): blocks the commit if validation has not passed.

The protected branch check runs first because it is the cheaper operation and the more fundamental violation.
There is no point checking validation status if the commit should not happen on this branch at all.

### pre-push hook

The pre-push hook mirrors the pre-commit hook structure: protected branch check first, then validation check.
This provides a second enforcement point at push time.
Even if an agent or human bypasses pre-commit (e.g. with `--no-verify`), the push hook catches it.
Having both hooks means the feedback is early (at commit time) but the enforcement is redundant (at push time).

### Why both hooks exist

Pre-commit gives fast feedback: the agent learns immediately that it cannot commit without validation.
Pre-push provides a safety net: if pre-commit was bypassed, the invalid state does not reach the remote.
The cost of running both is negligible (two shell script invocations), and the benefit is defence in depth.

## Tool Permission Defaults

### Why tracked permission configs exist

Each AI coding tool has its own mechanism for controlling which commands the agent can run without prompting the user.
Without pre-configured defaults, every new clone starts with zero approvals, and the human must manually approve each command the first time it runs.
This creates friction that slows the workflow and trains the human to click "approve" reflexively — the opposite of the intended safety model.

Tracked permission configs solve this by shipping a curated set of pre-approved commands with the repository.
The human reviews them once (in the PR that adds them), and every subsequent clone inherits the same baseline.

### The two-layer safety model

Tool permission configs and git hooks serve complementary roles:

1. **Tool-side permissions** reduce friction by pre-approving commands that are safe or that the workflow already gates through human checkpoints (e.g. `git push` requires explicit human approval at Step 11 before the agent runs it).
2. **Git hooks** enforce bright-line rules mechanically regardless of what the tool permits. Even if a tool auto-approves `git push`, the pre-push hook blocks it on a protected branch.

Neither layer is sufficient alone.
Tool permissions without hooks rely on instruction-following for safety-critical rules.
Hooks without tool permissions create constant approval prompts that add no safety value for read-only or local operations.

### Per-tool configuration

Each tool uses a different permission model.
The configs are kept consistent in intent (same commands are safe across all tools) but differ in format because each tool's mechanism is different.

**Claude Code** (`.claude/settings.json`) uses a per-command allowlist under `permissions.allow`.
Each entry is a pattern like `Bash(git push:*)` that matches a command prefix.
This is the most granular model — every permitted command is explicitly listed.

**Codex** (`.codex/config.toml`) uses sandbox-based permissions.
`approval_policy = "on-failure"` auto-approves commands inside the sandbox and escalates to the user only when a command fails sandbox restrictions.
`sandbox_mode = "workspace-write"` allows writes within the project directory.
There is no per-command allowlist; safety comes from sandbox confinement plus hooks.
Dangerous GitHub MCP tools (`push_files`, `create_or_update_file`, `delete_file`) are explicitly disabled.

**Gemini CLI** (`.gemini/settings.json`) uses a sandbox and trusted-folders model.
`tools.shell.allowedCommands = "all"` permits shell execution; safety comes from the sandbox layer and the `BeforeTool` hooks that block protected-branch operations.
There is no per-command allowlist.

**VS Code Copilot** (`.vscode/settings.json`) uses `chat.tools.terminal.autoApprove` with prefix-matched command names.
This is similar to Claude's model — each safe command is explicitly listed.

### What is pre-approved and why

Commands are organised into categories:

- **Git read** (`status`, `log`, `diff`, `show`, `branch`, `fetch`, etc.): zero side effects, always safe.
- **Git local write** (`checkout`, `add`, `commit`, `rebase`, `restore`, `stash`): reversible, no shared state affected.
- **Git remote** (`push`, `pull`): the workflow requires human confirmation at checkpoint steps before the agent runs these. Pre-approving the tool execution avoids a redundant prompt since the workflow and hooks already gate the action.
- **GitHub CLI** (`gh issue`, `gh pr`, `gh repo`): needed for the workflow's issue and PR operations.
- **Shell read utilities** (`ls`, `cat`, `grep`, `find`, `wc`, etc.): read-only, no risk.
- **File operations** (`mkdir`, `cp`, `mv`, `touch`): local and reversible.
- **Test runners** (`npm test`, `pytest`, `make`, etc.): needed for validation steps. Scoped to specific runners rather than broad `bash:*` wildcards.
- **Workflow scripts** (`run-validation.sh`, `install-hooks.sh`): the two scripts the workflow explicitly references.

### Why broad scripting permissions are excluded

Earlier iterations included `Bash(bash:*)` and `Bash(python:*)` in Claude's config.
These effectively bypass all other restrictions since any command can be run through `bash -c "..."`.
The current approach permits specific runners (`npm run`, `npx`, `pytest`, `make`) instead, preserving the principle that each permission is intentional and auditable.
