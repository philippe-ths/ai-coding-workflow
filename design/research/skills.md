# Skills and Progressive Disclosure

Primary-source notes on skills as an on-demand loading pattern and the progressive-disclosure approach to agent instruction.
See `design/research/README.md` for the citation convention.

---

## Anthropic Agent Skills progressive disclosure model {#anthropic-agent-skills-progressive-disclosure}

Source: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
Extracted: 2026-04-23
Finding: Anthropic defines Agent Skills as folders containing a `SKILL.md` plus optional scripts and resources, loaded through a three-level progressive disclosure scheme.
Level one is the YAML frontmatter (name and description), which is the only part that is always present in the system prompt; it provides the trigger signal Claude uses to decide whether to load the rest.
Level two is the `SKILL.md` body, pulled into context only when Claude judges the skill relevant to the current task.
Level three is any additional files in the skill directory, which Claude navigates to on demand via filesystem reads; executable scripts bundled with the skill are invoked via bash and only their output enters context, not their source.
Anthropic frames this layering as the mechanism that lets a single agent carry many skills without paying their full token cost up front, and recommends keeping `SKILL.md` body under roughly 500 lines, splitting into linked files beyond that.

---

## Skill description drives trigger selection {#skill-description-trigger-selection}

Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
Extracted: 2026-04-23
Finding: Anthropic's skill authoring guidance makes the frontmatter `description` field the load-bearing element for discovery: because only the frontmatter is always in the system prompt, Claude decides whether to load a skill almost entirely from its description.
The guide instructs authors to write descriptions in third person, to state both what the skill does and when to use it (concrete triggers, contexts, filenames, or command patterns), and to keep them within the 1024-character limit.
The stated failure mode is that a vague or first-person description leaves the model unable to distinguish which of many installed skills fits the current request, so the skill is either not invoked when it should be or invoked when it should not be.
Anthropic additionally exposes frontmatter controls (`disable-model-invocation`, `user-invocable`) to suppress model-driven triggering for side-effecting or human-only skills, treating the description as a discovery signal separate from the invocation policy.

---

## Instruction-Tool Retrieval quantifies savings from on-demand loading {#itr-on-demand-loading-savings}

Source: https://arxiv.org/abs/2602.17046
Extracted: 2026-04-23
Finding: Franko (2025) proposes Instruction-Tool Retrieval (ITR), a retrieval-augmented scheme that fetches, per step, only the minimal system-prompt fragments and the smallest necessary subset of tools rather than re-injecting a monolithic prompt and full tool catalog each turn.
On a controlled benchmark, ITR reduces per-step context tokens by 95%, improves correct tool routing by 32% relative, and cuts end-to-end episode cost by 70% compared to the monolithic baseline; the authors report the saved budget lets agents run 2-20x more loops inside the same context window.
The paper frames the monolithic baseline as re-ingesting long system instructions every turn, which drives up cost, latency, and tool-selection error rate, and argues savings compound with agent step count.
The result is a measurable primary source for the claim that on-demand loading of instructions and tools (the abstract pattern that skills implement) reduces token cost and improves routing accuracy versus a baseline that inlines everything; the numbers come from a single controlled benchmark in the paper, not an independently replicated study.

---

## Tool-to-Agent Retrieval and the context-dilution failure mode {#tool-to-agent-retrieval-context-dilution}

Source: https://arxiv.org/abs/2511.01854
Extracted: 2026-04-23
Finding: Lumer et al. (2025) introduce Tool-to-Agent Retrieval, a framework that embeds tools and their parent agents in a shared vector space connected by metadata, so retrieval can be granular at either the tool or agent level.
The paper's motivation is that when many tool descriptions are chunked together into one agent-level description and retrieved as a unit, fine-grained tool semantics get smeared; the authors label this "context dilution" and attribute suboptimal agent selection to it.
Evaluated across eight embedding models on the LiveMCPBench benchmark, the approach achieves consistent gains of 19.4% in Recall@5 and 17.7% in nDCG@5 over prior state-of-the-art agent retrievers.
The relevance to skills is mechanism-level: the same dilution argument applies to bundling multiple concerns into a single `SKILL.md` versus keeping each skill self-contained with its own discriminating description, because a retrieval or trigger decision over coarse, overloaded descriptions is less accurate than one over narrow, specific descriptions.

---

## Anthropic Building Effective AI Agents on tool and context design {#building-effective-agents-context-design}

Source: https://www.anthropic.com/engineering/building-effective-agents
Extracted: 2026-04-23
Finding: Anthropic's "Building Effective AI Agents" post treats the augmented LLM (an LLM plus retrieval, tools, and memory) as the base building block of agentic systems and argues that the primary design lever is how those augmentations are exposed to the model, not the orchestration logic around them.
The post recommends starting with the simplest possible prompt and adding multi-step agent structure only when simpler solutions fall short, measured against evaluations.
It stresses two design principles relevant to skills: keep the agent-computer interface (tool descriptions, schemas, instructions) clear and well-documented, because the model's performance tracks the quality of those descriptions; and prefer exposing few well-specified tools over many overlapping ones.
The post does not use the word "skill," but the guidance generalizes the underlying idea: the quality of on-demand, model-facing descriptions dominates agent behaviour, and description quality matters more than adding orchestration layers.
This supports the broader claim that skill-style extraction is a general pattern for any long-context agent system, not a Claude-specific artifact, while noting that the post is engineering guidance rather than a controlled study.

---
