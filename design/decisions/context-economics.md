# Context Economics

Covers the context budget constraints that govern what goes into `ai-workflow.md` and how progressive disclosure through reference sections and skills reduces the always-loaded token cost.

## Context budget

Every line in the file consumes context window tokens that compete with the actual task.
Research suggests frontier models reliably follow roughly 150-200 instructions, with degradation uniform across all rules as the count increases.
(See `design/research/token-efficiency-in-agentic-workflows.md#ifscale-instruction-compliance-decay`.)
The agent tool's own system prompt already consumes some of this budget before the workflow file loads.
This means every low-value line added dilutes the compliance probability of every high-value line.
Before adding a rule, ask: could the agent figure this out by reading the codebase?
If yes, do not add it.
If a boundary is bright-line and machine-checkable, prefer deterministic repo-local enforcement over repeated workflow wording.
Prefer fewer, higher-quality rules over comprehensive coverage.

## Progressive disclosure via lean steps

The placement rule for lean steps is in `design/decisions/rule-placement.md` under **Workflow steps should be lean**.
The economic rationale: keeping always-loaded steps short defers the token cost of detailed rules to reference sections, which are only parsed when the step points to them.
Long context degrades retrieval and instruction adherence even when the content is present.
(See `design/research/token-efficiency-in-agentic-workflows.md#chroma-context-rot`.)

## Skill loading as a context budget tool

Skills are the on-demand variant of reference sections.
For the qualification criteria for skill extraction, see `design/decisions/maintenance.md` under **File Splitting**.
Extracting a section to a skill means its token cost is paid only in the sessions that need it.
(See `design/research/skills.md#anthropic-agent-skills-progressive-disclosure` for the three-level disclosure model and `#itr-on-demand-loading-savings` for measured savings: 95% per-step context reduction, 70% end-to-end episode cost reduction, 32% relative improvement in tool routing accuracy on a controlled benchmark.)
Subagent context isolation is a stronger form of this tool: spawning a subagent for a bounded subtask gives it a clean context window with no accumulated session noise.
For when to use subagents, see `design/decisions/runtime-configuration.md`.

## Resource Discipline section

The `Resource Discipline` section in `ai-workflow.md` exists because an efficiency directive is unusually easy for the agent to misuse: every plausible misread trades correctness for cheapness, and the agent can always rationalise the trade as "protecting your quota." The section is worded to close those misreads rather than to state the goal in the abstract. Each line below names the misuse it defends against.

The framing is a single priority order, not two goals. "Protect context window" and "protect quota" pull against each other on the subagent axis: offloading work to a subagent keeps the main context lean but spends quota, so an agent told to do both will optimise whichever it ranks first. In testing, ranking context-cleanliness first produced indiscriminate subagent spawning — the agent minimised tokens in *its own* context while maximising *total* tokens burned. The section resolves this by making global token cost the variable to minimise, with correctness as a floor above both.

The floor is the load-bearing line. "Efficiency governs *how* you discharge a required step, never *whether*" defends against the central misuse: skipping or thinning verification, ground-truth sourcing, or failure analysis to save tokens. It is stated as a general rule, not an enumerated list of protected steps, because enumeration invites the agent to reason "this step is not on the list, so cost-cutting is allowed here." Verification and failure analysis are the steps most tempting to cut (failure analysis is the most expensive mode in the workflow and fires only after a "done" claim has already collapsed), but the rule protects every required step, including ones not foreseen here.

"Read and search narrowly" defends against under-reading ground truth — guessing at a value or interface instead of confirming it — by qualifying narrow reading with "only when you need them" and leaving ground-truth sourcing as a floored step that narrow reading cannot override. It deliberately does not enumerate `cat`-versus-`grep` mechanics, which the agent harness already governs; restating them would spend the budget the section is trying to protect.

The subagent line defends against the spray failure directly. It ties spawning to the two sanctioned purposes already documented under **Subagent use** in `design/decisions/runtime-configuration.md` (parallelism and clean context) and to the 15x token-cost caveat recorded there, then forbids spawning "as a reflex to empty your own context window." The spray failure is that 15x caveat materialising: the always-loaded line is the behavioural guard the rationale doc could not enforce on its own.
