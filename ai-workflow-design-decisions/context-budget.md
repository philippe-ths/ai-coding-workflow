# Context Budget — AI Workflow Design Decisions

**Context budget.**
Every line in the file consumes context window tokens that compete with the actual task.
Research suggests frontier models reliably follow roughly 150-200 instructions, with degradation uniform across all rules as the count increases.
The agent tool's own system prompt already consumes some of this budget before the workflow file loads.
This means every low-value line added dilutes the compliance probability of every high-value line.
Before adding a rule, ask: could the agent figure this out by reading the codebase?
If yes, do not add it.
If a boundary is bright-line and machine-checkable, prefer deterministic repo-local enforcement over repeated workflow wording.
Prefer fewer, higher-quality rules over comprehensive coverage.