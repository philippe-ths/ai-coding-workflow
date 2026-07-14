@ai-workflow.md
@project-context.md

You must confirm you have read both files and can invoke the "aiw-*" project skills before responding.

## Sub-agents and tools (Claude Code)

The workflow's routing guidance maps to these Claude Code tools. Route work out by its shape; review every returned result in the main loop.

- Broad multi-file search or reconnaissance: the Explore agent (read-only, fans out without flooding your context).
- Multi-step research or delegated implementation: the general-purpose agent.
- Parallel edits that would conflict: sub-agents with worktree isolation.
- Prior art or external ground truth the codebase cannot show: web search.
- Clean-context verification: a fresh general-purpose agent that did not write the code.