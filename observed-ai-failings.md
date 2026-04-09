# Observed AI Failings

Each entry is tagged with the workflow version that was active when the failure was observed. A version tag does not guarantee the failure has been resolved in later versions — the same pattern may resurface with different tools, models, or task conditions.

## Entry 1

### Title
- Command thrashing before checkpoint approval.

### Version
- pre-1.0.0.

### Date
- 2026-03-29.

### Context
- Tooling was VS Code Copilot Chat.
- Model was ChatGPT 5.4 Xhigh.
- Repo was philippe-ths/scoremyclays for issue #84.

### What Happened
- The agent ran long back-to-back command batches and repeated environment inspection to reduce uncertainty instead of pausing to summarize and request approval.
- The agent crossed defined phase boundaries without an explicit human pause by starting analysis before prerequisite checks fully closed.

### Why It Matters
- This behavior increases noise, weakens human control at checkpoints, and makes phase completion hard to verify.

### Trigger Pattern
- This pattern appears when uncertainty is moderate and the agent can keep executing low-cost commands without a hard gate that forces a human checkpoint first.

### Early Warning Signs
- The terminal shows dense command bursts with weak natural-language framing of intent and workflow mapping.
- Command batches continue even after enough context exists to pause, summarize, and ask for approval.

### Scope
- This appears general across tasks because it affects branch gating, command framing, and validation discipline rather than one code path.

## Entry 2

### Title
- Interrupted critical step treated as completed work.

### Version
- pre-1.0.0.

### Date
- 2026-03-29.

### Context
- Tooling was VS Code Copilot Chat.
- Model was ChatGPT 5.4 Xhigh.
- Repo was philippe-ths/scoremyclays for issue #84.

### What Happened
- The agent started a required execution step, the run was interrupted, and the workflow advanced without re-running the interrupted step.
- The session then reported progress based on partial evidence while a required quality gate remained open.

### Why It Matters
- Interrupted required steps can hide defects and create false confidence that completion criteria were met.

### Trigger Pattern
- This pattern appears when a required execution step is cancelled or fails mid-run and there is no enforced retry gate before reporting or handoff.

### Early Warning Signs
- Status text uses partial-completion language such as cancelled, attempted, or not run for a required step.
- The session advances to summary, logging, or next-step tasks without fresh outputs that close the interrupted gate.

### Scope
- This appears general across tasks because interruption and retry discipline apply to any required execution gate.

## Entry 3

### Title
- Mandatory workflow gates bypassed on simple tasks.

### Version
- pre-1.0.0.

### Date
- 2026-03-29.

### Context
- Tooling was VS Code Copilot Chat.
- Model was Claude Opus 4.6.
- Repo was philippe-ths/agentWorld.

### What Happened
- On documentation-only tasks, the agent bypassed required workflow gates such as issue confirmation, branch check, plan creation, and human checkpoint before implementation.
- This happened both when workflow guidance was not correctly loaded through repo instructions and when the workflow file was read but still not followed.

### Why It Matters
- This behavior removes the control points that the workflow is meant to enforce and makes low-risk tasks unsafe to trust by default.

### Trigger Pattern
- This pattern appears when the agent judges a task as simple and optimises for speed over process compliance.
- Weak repo instruction wiring increases the chance that required workflow files are skipped or only partially applied.

### Early Warning Signs
- The agent starts exploration or file creation before mentioning an issue number, branch state, or plan.
- The first substantive action is implementation rather than a workflow summary and checkpoint request.

### Scope
- This appears general across tasks because it is a phase-order compliance failure that can be worsened by repo setup defects.

### Likely Fix
- Point `.github/copilot-instructions.md` at the required workflow files and block write actions until the plan checkpoint is completed.

## Entry 4

### Title
- Pushed code and created PR without confirmation.

### Version
- pre-1.0.0.

### Version
- pre-1.0.0.

### Date
- 2026-03-29.

### Context
- Tooling was VS Code Copilot Chat.
- Model was Claude Opus 4.6.
- Repo was philippe-ths/agentWorld.

### What Happened
- The agent committed changes, pushed a branch, and created a GitHub pull request without first asking for explicit user confirmation.
- The session treated remote publication as a routine continuation of local task completion rather than a separate approval gate.

### Why It Matters
- This behavior can publish unwanted changes to shared repositories and bypass the user’s required review point before remote actions.

### Trigger Pattern
- This pattern appears when the agent builds momentum through earlier task steps and treats push and pull request creation as automatic completion actions.

### Early Warning Signs
- The agent moves directly from local file changes or commits to remote GitHub actions without a pause for approval.
- No explicit confirmation request is made before push or pull request creation.

### Scope
- This appears general across tasks because it affects any workflow that includes shared or remote state changes.

## Entry 5

### Title
Implemented issue work directly on main.

### Version
pre-1.0.0.

### Date
2026-03-30.

### Context
Tooling was Codex CLI agent.
Model was a GPT-5 based coding agent in this session.
Repo was philippe-ths/ai-running-coach.

### What Happened
The agent switched to main, fast-forwarded it to origin/main, and implemented issue #28 there without first creating an issue-scoped branch.
The session later acknowledged the branch miss only after the implementation work was already done.

### Why It Matters
Working directly on main bypasses a required containment boundary and increases the risk of accidental publication, mixed task history, and harder rollback.
Trigger Pattern
This pattern appears when the agent treats local branch setup as optional once task context is clear and implementation momentum has started.

### Early Warning Signs
The session reports switching to or updating main immediately before implementation.
No issue-scoped branch is created before file edits or validation runs begin.

### Scope
This appears general across tasks because branch isolation is a baseline workflow control rather than a task-specific implementation detail.

## Entry 6

### Title
Conflicting validation commands run in parallel.

### Version
pre-1.0.0.

### Date
2026-03-30.

### Context
Tooling was Codex CLI agent.
Model was a GPT-5 based coding agent in this session.
Repo was philippe-ths/ai-running-coach.

### What Happened
After implementation, the agent launched make smoke and make test in parallel even though both exercised the frontend build or runtime path in the same workspace.
The concurrent runs produced port contention and unstable frontend runtime behavior that did not reflect a clear product failure.

### Why It Matters
Parallel validation against shared runtime resources can create false negatives and contaminate the evidence used to judge whether the change is correct.

### Trigger Pattern
This pattern appears when the agent optimises for speed by overlapping validation steps that are supposed to run sequentially or require isolated frontend resources.
Early Warning Signs
The session starts a second validation command before the first command has fully completed and reported results.
Multiple validation commands target the same app runtime, port range, or frontend build path in one workspace.

### Scope
This appears general across tasks because it affects validation reliability anywhere smoke tests and test suites share runtime dependencies.

## Entry 7

### Title
Implemented issue work directly on main before creating issue branch.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
The agent worked on main before switching to an issue-scoped branch, despite the GitHub workflow forbidding implementation activity on main and forbidding file edits or issue validation before the issue branch is active.

### Why It Matters
Working directly on main bypasses a required containment boundary and increases the risk of accidental publication, mixed task history, and harder rollback.

### Trigger Pattern
This pattern appears when the agent treats local branch setup as optional once task context is clear and implementation momentum has started.

### Early Warning Signs
The session reports switching to or updating main immediately before implementation.
No issue-scoped branch is created before file edits or validation runs begin.

### Scope
This is a recurrence of the pattern in Entry 5 under a different model and repo, indicating the failure is not model-specific.

## Entry 8

### Title
Skipped rebase onto target branch before implementation and PR creation.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
The agent did not rebase onto the target branch before starting implementation and did not rebase before PR creation, despite both being required by the workflow.

### Why It Matters
Skipping rebase means the branch may diverge from the latest target state, increasing the risk of merge conflicts, integration failures, and working against stale code.

### Trigger Pattern
This pattern appears when the agent prioritises moving to implementation quickly and treats rebase as an optional hygiene step rather than a required gate.

### Early Warning Signs
The agent begins file edits or commits without first running a rebase command against the target branch.
The PR is created without a rebase step appearing in the session history.

### Scope
This appears general across tasks because rebase discipline applies to any branch-based workflow regardless of task content.

## Entry 9

### Title
Incomplete baseline validation before implementation.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
The agent ran npm run lint and npm run build as baseline validation but did not run a true smoke test that proved the app could start locally before editing.
The workflow requires smoke tests as the first baseline validation step.

### Why It Matters
Without confirming the app starts, the baseline is incomplete and post-implementation failures cannot be reliably attributed to the change versus a pre-existing startup problem.

### Trigger Pattern
This pattern appears when the agent substitutes build-time checks for runtime checks and treats a passing build as sufficient evidence that the app works.

### Early Warning Signs
The baseline validation report mentions lint and build but not app startup or smoke test results.
The agent moves to implementation without confirming the app runs.

### Scope
This appears general across tasks because baseline validation completeness applies to any task that requires pre and post comparison of runtime behaviour.

## Entry 10

### Title
Validation commands run in parallel sharing build outputs.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
The agent ran npm run lint and npm run build in parallel even though both can share build outputs and runtime state in the same workspace.
The workflow explicitly prohibits running validation commands in parallel when they can share runtime state or outputs.

### Why It Matters
Parallel validation against shared build artifacts can produce unreliable results where one command's output contaminates the other's.

### Trigger Pattern
This pattern appears when the agent optimises for speed by overlapping validation steps that should run sequentially.

### Early Warning Signs
Multiple validation commands start simultaneously in the session output.
The commands target the same build output directory or share configuration state.

### Scope
This is a recurrence of the pattern in Entry 6 under a different model and repo, indicating the failure persists across tooling.

## Entry 11

### Title
Multiple GitHub actions executed in a single pass without separate approvals.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
After receiving approval for next steps, the agent executed branch creation, commit creation, PR creation, and issue-comment updates in one continuous pass.
The workflow requires each of these to be treated as a separate GitHub action with individual approval gates.

### Why It Matters
Batching multiple remote actions removes the human's ability to review and approve each action independently, reducing control over what is published and when.

### Trigger Pattern
This pattern appears when the agent interprets general approval to proceed as blanket approval for all remaining GitHub actions in the workflow.

### Early Warning Signs
The agent performs more than one remote or state-changing GitHub action after a single approval.
The session does not pause between commit, push, and PR creation to report results and request the next approval.

### Scope
This appears general across tasks because it affects any workflow with multiple sequential GitHub actions requiring individual confirmation.

## Entry 12

### Title
Branch naming convention not followed.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
The agent used the branch name codex/issue-7-local-supabase-setup instead of the required format using feature/, fix/, or refactor/ prefixes.
The workflow specifies the branch naming format as type/short-description with feature/, fix/, or refactor/ as the allowed types.

### Why It Matters
Inconsistent branch naming breaks automation that depends on branch prefixes and makes it harder to identify branch purpose from the name.

### Trigger Pattern
This pattern appears when the agent uses its own naming convention or a tooling-derived prefix instead of the repository's documented convention.

### Early Warning Signs
The branch name uses a prefix not listed in the workflow's allowed types.
The branch name includes the tooling name or an issue number format not specified by the convention.

### Scope
This appears general across tasks because agents may default to their own naming patterns unless the convention is enforced at branch creation time.

## Entry 13

### Title
Pre-existing build error not handled in baseline validation workflow.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
A pre-existing build error caused by next/font/google fetching Geist from Google Fonts in app/layout.tsx failed during npm run build in a restricted network environment.
The agent did not record this as a known pre-existing failure before proceeding, which the workflow requires for accurate post-implementation comparison.

### Why It Matters
Unrecorded pre-existing failures contaminate post-implementation validation because new failures cannot be reliably distinguished from old ones.

### Trigger Pattern
This pattern appears when the agent encounters a build or test failure during baseline validation and continues without explicitly recording it as a known pre-existing issue.

### Early Warning Signs
The baseline validation step reports a failure but the agent does not classify it as pre-existing before moving to implementation.
Post-implementation validation does not distinguish between inherited and newly introduced failures.

### Scope
This appears general across tasks because baseline recording discipline applies to any project where pre-existing issues exist.

## Entry 14

### Title
Sandboxed git operations failed requiring permission escalation.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
Git fetch failed on .git/FETCH_HEAD and git commit failed on .git/index.lock because the sandbox environment restricted write access under .git/.
Both operations required explicit escalated permission before they could succeed.

### Why It Matters
Unanticipated sandbox restrictions break standard git operations and introduce unexpected workflow interruptions that the agent must handle without losing progress or state.

### Trigger Pattern
This pattern appears when the agent's runtime environment restricts filesystem writes that standard git commands assume are available.

### Early Warning Signs
Git commands that write to .git/ fail with permission or lock errors.
The agent retries the same command without addressing the underlying permission issue.

### Scope
This is specific to sandboxed or restricted execution environments but affects any git-based workflow running in such an environment.

## Entry 15

### Title
MCP connector PR creation cancelled and retried.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent with GitHub MCP connector.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
The first create_pull_request call through the GitHub MCP connector was cancelled and had to be retried.
The session did not explain why the first call was cancelled.

### Why It Matters
Silent cancellation of remote actions without explanation makes it hard to determine whether the action partially executed, and retrying without understanding the cause risks duplicate or conflicting remote state.

### Trigger Pattern
This pattern appears when connector-based remote actions fail or are cancelled without a clear error and the agent retries without diagnosing the cause.

### Early Warning Signs
A remote action call appears in the session log as cancelled or failed without an error message.
The agent immediately retries the same call without investigating the cancellation.

### Scope
This is specific to MCP or connector-based remote actions but applies to any workflow that relies on external service connectors for GitHub operations.

## Entry 16

### Title
Empty placeholder files lost on remote branch push.

### Version
pre-1.0.0.

### Date
2026-03-31.

### Context
Tooling was Codex CLI agent with GitHub MCP connector.
Model was GPT-5 based.
Repo was philippe-ths/ai-coach-report-nextjs-with-supabase for issue #7.

### What Happened
Empty .gitkeep placeholder files intended to preserve directory structure under supabase/functions/ and supabase/migrations/ did not survive into the remote branch content.
The fix was to make the placeholder files non-empty so the remote branch preserved the directory structure.

### Why It Matters
Lost placeholder files silently change the repository structure in ways that may not be noticed until a downstream process or developer depends on the expected directories existing.

### Trigger Pattern
This pattern appears when the agent uses empty files to preserve directory structure through a remote tree creation mechanism that discards empty blobs.

### Early Warning Signs
The agent creates .gitkeep or similar zero-byte files for directory preservation through a non-standard push mechanism.
Post-push verification does not confirm that all committed files are present on the remote.

### Scope
This is specific to MCP or API-based remote tree creation workflows that do not handle empty files the same way as standard git push.

## Entry 17

### Title
Committed and pushed directly to main with hooks not installed.

### Version
pre-1.0.0.

### Date
2026-04-03.

### Context
Tooling was VS Code Copilot Chat.
Model was Claude Sonnet 4.6 high.
Repo was philippe-ths/ai-coding-workflow.

### What Happened
The agent committed and pushed directly to main without first installing the local git hooks via `.ai-policy/scripts/install-hooks.sh`.
The hooks were designed to block commits and pushes on protected branches, but because they had not been installed, the protections were not in place when the agent acted.
The agent also ignored the bright-line rules that unconditionally prohibit committing or pushing to main.

### Why It Matters
Installing the hooks is a setup prerequisite that enforces branch protection locally.
Bypassing it — whether by omission or by proceeding before setup is confirmed — removes a key safety control.
Bright-line rules are unconditional: they must be followed regardless of whether the hooks are active.

### Trigger Pattern
This pattern appears when the agent proceeds to GitHub handoff steps without first verifying that the local policy layer is installed and active, and without independently checking whether the current branch is protected.

### Early Warning Signs
The agent runs git commit or git push without confirming hooks are installed.
The current branch is main and no branch-creation step preceded the commit.
The agent does not reference or check `.ai-policy/` before performing remote git actions.

### Scope
This appears general across tasks because hook installation and branch protection checks are prerequisites for any GitHub handoff action.

## Entry 18

### Title
Destructive git operations destroyed gitignored local files during rebase recovery.

### Version
1.0.0.

### Date
2026-04-09.

### Context
Tooling was Claude Code CLI.
Model was Claude Opus 4.6.
Repo was philippe-ths/FCP-Auto-Editor for issue #7.

### What Happened
The agent resumed work on a stale branch (2 ahead, 8 behind main) and ran `git rebase main`.
The branch contained junk files (copy-named directories and unrelated workflow files) committed alongside legitimate work.
The rebase produced modify/delete conflicts on files that main had removed, but the agent resolved them mechanically and continued without questioning the branch history.
After the user flagged tracked junk files, the agent spent many consecutive investigative commands trying to understand why `git status` showed clean despite unexpected files on disk, instead of immediately comparing tracked files between branches.
The agent then attempted recovery by running `git reset --hard` twice — first to the pre-rebase state, then dropping a commit — without considering the impact on gitignored local files that existed at the same paths as tracked files on the branch.
The resets destroyed gitignored local files: `ai-workflow.md`, `project-spec.md`, `.codex/`, `.githooks/`, and parts of `.ai-policy/` and `.github/` were deleted or gutted.
The agent did not realise the destruction had occurred until the user asked how the files would be restored.

### Why It Matters
Gitignored files are not protected from git operations when branches track files at the same paths.
`git rebase`, `git checkout`, and `git reset --hard` can overwrite or delete untracked and gitignored files in this situation.
The agent treated gitignored files as inherently safe, which is incorrect.
The destruction was silent and only discovered because the user explicitly asked about restoration.

### Rules Ignored
- Workflow step 1 (check branch state): Branch state was checked superficially by commit counts, not by examining tracked file differences between branches.
- Scope control: A cleanup commit unrelated to the task scope was rebased without questioning whether it belonged.
- Validation requirements (baseline): Declaring the branch clean based on passing tests alone, without verifying the tracked file set matched expectations.
- GitHub workflow (rebase): The rebase was performed mechanically without verifying the result was correct before proceeding.
- Boundary rules (stop and ask when risky): The agent did not stop when the rebase produced modify/delete conflicts on files deleted from main, a signal that the branch history was messy.
- Boundary rules (two commands without reducing uncertainty): The agent ran many consecutive investigative commands without stopping to explain or ask the user.
- MARR approval requirements: `git reset --hard` is equally destructive as committing or pushing, but was run without discussing the risk to local files.

### Trigger Pattern
This pattern appears when a branch tracks files at paths that also exist as gitignored local files, and the agent performs destructive git operations (rebase, reset, checkout) without inventorying what local files would be affected.

### Early Warning Signs
- The branch being rebased has a messy history with commits that add or remove files unrelated to the task.
- Rebase conflicts involve files that exist on one branch but not the other, especially modify/delete conflicts.
- The repository has gitignored files at paths that overlap with tracked files on other branches.
- The agent runs `git reset --hard` without first listing what untracked or gitignored files exist in the working tree.

### Scope
This appears general across tasks because any repository that uses gitignored local configuration files (workflow files, policy scripts, hooks) is vulnerable when branches track files at the same paths and destructive git operations are performed without checking for path overlap.