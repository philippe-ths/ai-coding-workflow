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