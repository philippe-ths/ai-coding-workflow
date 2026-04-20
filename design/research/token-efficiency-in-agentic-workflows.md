# Token Efficiency in Agentic Workflows

Primary-source notes on context economics, instruction compliance, and model efficiency research.
See `design/research/README.md` for the citation convention.

---

## Chroma context rot {#chroma-context-rot}

Source: https://research.trychroma.com/context-rot
Extracted: 2026-04-20
Finding: Retrieval accuracy and instruction adherence degrade measurably as context length grows, even when the relevant content is present. The degradation is not linear — it accelerates beyond certain thresholds and is not fully mitigated by reranking. The study calls this "context rot."

---

## IFScale instruction-compliance decay {#ifscale-instruction-compliance-decay}

Source: https://arxiv.org/abs/2501.16273
Extracted: 2026-04-20
Finding: IFScale (Instruction Following Scale) measures compliance rate as the number of active instructions increases. Frontier models reliably follow roughly 150-200 instructions before compliance degrades uniformly across all rules. The degradation affects all instructions equally, not just later ones, so there is no safe position for important rules in a long file.

---

## Liu, Wharton — thinking effort cost/accuracy trade-off {#liu-wharton-thinking-effort}

Source: https://arxiv.org/abs/2503.19922
Extracted: 2026-04-20
Finding: Extended thinking improves task accuracy on complex reasoning tasks but the marginal gain diminishes at higher effort levels. The cost/accuracy curve is convex: moderate thinking effort captures most of the gain; maximum effort provides smaller incremental improvement at disproportionately higher token cost. The crossover point depends on task complexity.

---

## RLHF length bias {#rlhf-length-bias}

Source: https://arxiv.org/abs/2310.03744
Extracted: 2026-04-20
Finding: Models trained with RLHF from human preference data exhibit systematic length bias — they produce responses that are longer than the human rater's optimal preference because verbose responses were rated higher during training. This affects output token cost and increases context accumulation in multi-turn sessions. Explicit brevity instructions mitigate the bias but must be placed close to the generation point to be effective.

---

## Prompt caching structure {#prompt-caching-structure}

Source: https://www.anthropic.com/news/prompt-caching
Extracted: 2026-04-20
Finding: Anthropic's prompt caching reduces per-request latency and cost by reusing the KV cache for stable prefixes. Cache hits require the prefix to be identical to a prior request. Any change to the cached prefix (appending new content, modifying earlier content) invalidates the cache for the changed position and all positions after it. The cache has a 5-minute TTL by default. Maximum cost savings come from structuring prompts so that stable content (system prompt, workflow file, project context) forms a single unmodified prefix that persists across turns.
