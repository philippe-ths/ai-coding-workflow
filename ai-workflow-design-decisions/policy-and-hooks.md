# Policy and Hooks — AI Workflow Design Decisions

Covers the design decisions behind the `.ai-policy/` deterministic enforcement layer and the `.githooks/` git hooks.

## Deterministic Policy System (.ai-policy/)

### Why deterministic enforcement exists

The workflow file instructs the agent, but instruction compliance degrades as context grows and task complexity increases.
Bright-line mechanical rules (do not commit on a protected branch, do not commit without passing validation) are too important to rely on instruction-following alone.
The `.ai-policy/` directory moves these rules into deterministic enforcement: shell scripts that block the action at the Git level regardless of whether the agent remembered the rule.

This follows the maintenance rule "When a rule has both an advisory form and an enforcement form, keep the advisory form once in `ai-workflow.md` and keep the enforcement form in repo-local deterministic policy."
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
