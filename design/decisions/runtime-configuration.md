# Runtime Configuration

Covers thinking effort defaults, output brevity, prompt caching structure, and subagent use.

## Thinking effort

Extended thinking (where available) increases task accuracy at higher token cost.
Set thinking effort to match task complexity: use high or maximum effort for planning and ambiguous tasks; use lower effort for mechanical tasks like cross-reference updates or file moves.
(See `design/research/token-efficiency-in-agentic-workflows.md#liu-wharton-thinking-effort` for the cost/accuracy trade-off data.)
Do not run extended thinking on every step of a multi-step workflow; reserve it for the steps that require judgment.

## Output brevity

Language models exhibit RLHF length bias: they tend to produce longer responses than necessary because verbose responses were rewarded during training.
(See `design/research/token-efficiency-in-agentic-workflows.md#rlhf-length-bias`.)
Output brevity instructions reduce this noise.
Place brevity instructions close to the point of generation — in the system prompt or immediately before the relevant task instruction — rather than buried in a long file where context rot degrades their effect.
(See `design/research/token-efficiency-in-agentic-workflows.md#chroma-context-rot`.)

## Prompt caching structure

Prompt caching reduces per-request cost and latency on repeated context.
Cache the stable prefix — system prompt, workflow file, project context — separately from the dynamic per-task input.
Avoid appending to the cached prefix mid-session; breaks to the cache boundary invalidate the cache.
(See `design/research/token-efficiency-in-agentic-workflows.md#prompt-caching-structure` for cache hit rate benchmarks.)

## Subagent use

Subagents are useful for two distinct purposes: parallelising independent subtasks and isolating context for bounded subtasks.

**Parallelisation.**
Run independent subtasks (e.g. searching multiple directories, fetching multiple URLs) as concurrent subagents rather than sequentially in the main session.
Only parallelise tasks with no data dependency between them.
(See `design/research/subagents.md#anthropic-multi-agent-research-system` for measured gains from parallel subagent decomposition, and the 15x token cost caveat relative to single-agent runs.)

**Context isolation.**
A subagent starts with a clean context window.
Use a subagent when the main session has accumulated substantial noise (long tool call history, many prior edits) and the next subtask is bounded enough to be briefed from scratch.
Brief the subagent fully: it has no memory of the parent session.
(See `design/research/subagents.md#claude-agent-sdk-subagents` for the no-memory and no-nesting facts, `#effective-context-engineering-subagents` for subagents as a context-compaction primitive, and `#anthropic-subagent-briefing` for the objective/output-format/tools/boundaries briefing requirement and the duplicate-work failure mode from vague briefs.)

**When not to use subagents.**
Do not spawn a subagent for tasks that require access to the accumulated context of the main session (e.g. applying a fix that depends on earlier diagnostic output).
Do not use subagents to avoid thinking through a problem; the parent agent is responsible for synthesis.
(See `design/research/subagents.md#cognition-dont-build-multi-agents` for the shared-context failure case, and `#multi-agent-failure-modes` for the coordination-cost taxonomy.)
