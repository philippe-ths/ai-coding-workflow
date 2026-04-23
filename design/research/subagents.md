# Subagents and Multi-Agent Decomposition

Primary-source notes on subagent use: parallelisation, context isolation, and decomposition boundaries.
See `design/research/README.md` for the citation convention.

---

## Anthropic multi-agent research system — parallel subagents and isolated context windows {#anthropic-multi-agent-research-system}

Source: https://www.anthropic.com/engineering/multi-agent-research-system
Extracted: 2026-04-23
Finding: Anthropic's Research feature uses an orchestrator-worker architecture in which a lead agent spawns 3-5 subagents that run in parallel, each with its own context window and its own set of tool calls. In internal evaluations, a Claude Opus 4 lead with Claude Sonnet 4 subagents outperformed single-agent Claude Opus 4 by 90.2% on research tasks; the post attributes the gain primarily to token budget spread across multiple independent context windows rather than a single accumulating one, and to concurrent exploration of independent directions. The post explicitly scopes this gain to breadth-first queries where subtasks are independent; it does not claim the pattern helps when subtasks depend on shared intermediate state. Anthropic also reports the cost: agents use ~4x the tokens of chat and multi-agent systems use ~15x, so the pattern is recommended only when the task value justifies that multiplier.

---

## Anthropic multi-agent research system — briefing requirements for subagents {#anthropic-subagent-briefing}

Source: https://www.anthropic.com/engineering/multi-agent-research-system
Extracted: 2026-04-23
Finding: In the same post, Anthropic reports that short or vague subagent instructions ("research the semiconductor shortage") caused subagents to duplicate each other's searches, misinterpret scope, or leave gaps — in one example, one subagent investigated the 2021 automotive chip crisis while two others redundantly covered 2025 supply chains. The fix was to require each subagent brief to contain an explicit objective, output format, guidance on which tools and sources to use, and clear task boundaries. The post frames this as a direct consequence of each subagent starting with no knowledge of the lead's plan or of sibling subagents' work: whatever the lead does not write into the brief, the subagent does not have.

---

## Claude Agent SDK subagents — isolated context as a feature, not a side effect {#claude-agent-sdk-subagents}

Source: https://docs.claude.com/en/docs/agent-sdk/subagents
Extracted: 2026-04-23
Finding: The Claude Agent SDK documents subagents as specialised assistants that each run in their own context window with their own system prompt, tool allowlist, and permissions. The docs describe the isolation as the point of the primitive: a subagent consumes large or verbose intermediate output (test logs, documentation, file scans) inside its own window and returns only a summary to the orchestrator, keeping the main conversation's context clean. The docs also state that subagents cannot spawn further subagents — nested delegation must be chained from the main conversation — and that a subagent invocation is a one-shot with no memory across invocations.

---

## Anthropic "Effective context engineering" — subagents as a compaction mechanism {#effective-context-engineering-subagents}

Source: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
Extracted: 2026-04-23
Finding: Anthropic's context-engineering post lists subagents alongside compaction, tool-result clearing, and structured note-taking as techniques for managing long-horizon context. The stated role of subagents is compression: a specialised subagent with a clean window can sift through large volumes of information and return only the tokens the main agent needs, rather than the main agent accumulating all of that material in its own window. The post positions this as complementary to a high-level plan held by the main agent — the main agent coordinates, subagents do focused deep work — rather than as a replacement for a single coherent planner.

---

## Cognition "Don't Build Multi-Agents" — decomposition fails when subtasks share implicit decisions {#cognition-dont-build-multi-agents}

Source: https://cognition.ai/blog/dont-build-multi-agents
Extracted: 2026-04-23
Finding: Cognition's Walden Yan argues that splitting a task across parallel subagents breaks down when the subtasks carry implicit decisions that need to stay consistent. The worked example is a Flappy Bird clone split into a "build the background" subagent and a "build the bird" subagent: the subagents independently pick incompatible art styles and physics, and the parent cannot reconcile the outputs because the decisions were never surfaced. Cognition states two principles — share full context (not just messages) across decisions, and do not split decision-making in ways that can conflict — and concludes that for reliability-critical work a single linear agent with continuous context is preferable to parallel subagents. This directly nuances the Anthropic post: the parallel-subagent pattern is strong for breadth-first independent search and weak for tasks whose subtasks depend on shared implicit state, so decomposition boundaries should be drawn where subtask outputs are genuinely independent.

---

## "Why Do Multi-Agent LLM Systems Fail?" — catalogue of decomposition failure modes {#multi-agent-failure-modes}

Source: https://arxiv.org/abs/2503.13657
Extracted: 2026-04-23
Finding: Cemri et al. present a systematic study of LLM multi-agent system failures across multiple frameworks and tasks, cataloguing 14 fine-grained failure modes grouped into three categories, including specification/design issues, inter-agent misalignment (breakdowns in information flow between agents during execution), and task verification failures. The paper reports that inter-agent misalignment failures are not reliably fixed by better communication protocols or larger context alone — they require the agents to reason about each other's state, which current systems do poorly. The practical implication for subagent use is that decomposition is not free: every split introduces a coordination surface where information can be lost or contradicted, so the expected value of parallelisation has to exceed the expected cost of these failure modes for a given task.

---
