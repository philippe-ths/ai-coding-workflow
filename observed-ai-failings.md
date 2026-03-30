# Observed AI Failings

## Entry 1

### Title
- Command thrashing before checkpoint approval.

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