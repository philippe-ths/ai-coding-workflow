# Observed AI Failings Guide — AI Workflow Design Decisions

Covers how to record entries in `observed-ai-failings.md`, including writing guidelines and the entry template.

## Recording Guidelines

Use `observed-ai-failings.md` file to record concrete AI-agent failure patterns seen in real sessions.
Keep entries short.
Write one sentence per line.
Record what happened, not theories unless they are useful.

---

## Entry Template

### Title
- [Short name for the failure pattern.]

### Version
- [Current version from `ai-workflow.md`.]

### Date
- [YYYY-MM-DD]

### Context
- [Tooling or environment, e.g. VS Code Copilot, ChatGPT app, CLI agent.]
- [Model if known, e.g. GPT-5.4.]
- [Repo or project if relevant.]

### What Happened
- [Describe the observed behaviour in one sentence.]
- [Add one more sentence only if needed.]

### Why It Matters
- [State the practical cost or risk in one sentence.]

### Trigger Pattern
- [State what seemed to trigger it in one sentence.]
- [Use "Unknown" if unclear.]

### Early Warning Signs
- [List the first visible sign.]
- [List the second visible sign if useful.]

### Scope
- [State whether this seems local to one workflow step or general across tasks.]
