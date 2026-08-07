# Enforcement Layers

Covers the design decisions behind the `.ai-policy/` deterministic enforcement layer and the `.githooks/` git hooks.

The canonical rule for where in `ai-workflow.md` a deterministic boundary should be mentioned is in `design/decisions/rule-placement.md` under **Deterministic policy placement**.

## Deterministic Policy System (.ai-policy/)

### Why deterministic enforcement exists

The workflow file instructs the agent, but instruction compliance degrades as context grows and task complexity increases.
Bright-line mechanical rules (do not commit on a protected branch, do not commit without passing validation) are too important to rely on instruction-following alone.
(See `design/research/deterministic-enforcement.md#hierarchical-safety-cost-of-compliance` for measured inconsistency of prompt-level safety directives, `#longsafety-long-context-degradation` for safety-rate collapse under long context even when short-context safety is intact, and `#lifbench-instruction-stability` for instruction-following instability across input length intervals.)
The `.ai-policy/` directory moves these rules into deterministic enforcement: shell scripts that block the action at the Git level regardless of whether the agent remembered the rule.
(See `design/research/deterministic-enforcement.md#camel-control-flow-enforcement` for a measured example of external control-flow enforcement providing provable safety where prompt-level rules do not, and `#nemo-guardrails-programmable-rails` for the framework-level argument that runtime rails independent of the underlying LLM complement alignment rather than replace it.)

This follows the dual-form placement rule in `design/decisions/rule-placement.md` under **Rule Placement**.
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

It answers "where am I standing?", which is the right question at commit time, when the ref being written is the current branch.
At push time the target is explicit, so `.githooks/pre-push` runs `check-push-refs.sh` first and skips this check for pushes that write to no branch: tag-only pushes and delete-only pushes.
The delete exemption exists because post-merge cleanup runs from the protected branch by nature — you switch back to it, then delete the branch you just merged — so a current-branch rule rejects the normal cleanup path.
Nothing is lost by the exemption: a deletion naming a protected branch has already been rejected by `check-push-refs.sh`, which reads the resolved refs.

### Validation state tracking

The validation system uses a state file (`validation.status`) with three states: `running`, `passed`, `failed`.
A pass is recorded as `passed <fingerprint>`; the other two imply no particular tree and stay bare.

`run-validation.sh` orchestrates the flow: it sets the state to `running`, runs the configured validation command, and sets the state to `passed` or `failed` based on the result.
The `running` state plus a trap on exit ensures that if the script is interrupted or crashes, the state reverts to `failed` rather than remaining `passed` from an abandoned run.

`check-validation.sh` reads the state file and blocks the Git action unless the state is `passed` **and** the recorded fingerprint matches the current working tree.

### Why a pass is tied to a tree

A bare result records that validation passed, not what it passed against.
The gate then answers a weaker question than the one it exists to ask: it confirms that some validation run succeeded at some point, when what matters is whether the content being committed is the content that was validated.
The two diverge the moment a file is edited after the run, and the gap is invisible because the state still reads `passed`.
This failed in the direction that costs most — it reported green — and the only workaround was to remember to re-run validation immediately before every commit, putting the guarantee back on human memory, which is what the deterministic layer exists to remove.

`tree-fingerprint.sh` produces the fingerprint, hashing tracked and untracked-not-ignored paths and their content through `git hash-object`.
Using git's own hashing rather than `shasum` or `sha256sum` avoids a portability split between platforms, and git is already a hard dependency of every hook here.

Three exclusions are deliberate.
Ignored files are out because validation does not read them, so changing one is not a reason to revalidate.
The state file itself is excluded by explicit path rather than by relying on the ignore rules, because the fingerprint is written into that file: in a target repository that had not ignored it, every recorded result would invalidate itself on the next read, bricking the gate.
Deleted-but-tracked files are named by `git ls-files --deleted` rather than hashed, since hashing a missing path would abort the run on any ordinary deletion.

Two further exclusions are what make the gate usable rather than merely correct.
Index state is excluded, because `git add` changes whether a modification is staged and not what any file contains.
HEAD is excluded, because committing moves it while leaving every file on disk identical.
Including either was tried and both broke the ordinary sequence: staging invalidated the pass that had just been recorded, and committing invalidated it again so that every push demanded a second validation run.
Neither block corresponded to any change in what validation had read.
This matters more than the precision it gives up — a fingerprint keyed to history would distinguish the same edit before and after a rebase — because a gate that fires on the normal path gets routed around, and a bypassed gate enforces nothing.

One case refuses outright.
git reports a path containing a quote, a backslash, or a control character in quoted form, and that quoted string no longer names a file on disk.
Such a file would drop out of the content hashing while still appearing in the path list, so edits to it would not move the fingerprint — the same fail-open shape this change exists to close, reintroduced in a corner.
The script therefore aborts with the offending paths named rather than producing a fingerprint that covers less than it appears to.
Paths containing spaces are not quoted and need no special handling.

The fingerprint's stability is the load-bearing property, and the risk runs opposite to the defect it fixes.
A fingerprint that differs between two runs over an identical tree would block every commit in every repository that installs this layer, so `test-validation-state.sh` pins stability before it tests anything that depends on it.

Two limits are known and accepted.
The fingerprint is taken after the validation command returns, so a validation run that mutated a tracked file would fold that mutation into the recorded result.
The pre-commit gate fingerprints the working tree rather than the index, so committing a subset of a validated tree passes; this matches what validation actually ran against, which is the whole tree.

`mark-validation-pass.sh` and `mark-validation-fail.sh` exist as manual overrides.
They allow the human to set validation state directly when the automated flow is not appropriate (e.g. the project has no tests yet, or a known-failing test needs to be bypassed for a specific commit).
These are escape hatches, not normal workflow paths.
`mark-validation-pass.sh` still stamps the current fingerprint: the override exists to skip running validation, not to exempt the result from belonging to the content being committed.

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
(See `design/research/deterministic-enforcement.md#google-sre-defense-in-depth` for the independent-layers-and-compartmentalization principle applied to system reliability.)

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
(See `design/research/deterministic-enforcement.md#claude-code-sandbox` for a first-party example of OS-level sandboxing complementing tool-side permissions, and `#nemo-guardrails-programmable-rails` for the framework argument that runtime rails are independent of and complementary to model alignment.)

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
