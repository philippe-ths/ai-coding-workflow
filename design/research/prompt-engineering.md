# Prompt Engineering and Instruction Following

Primary-source notes on prompt structure, instruction format, and their effect on model compliance.
See `design/research/README.md` for the citation convention.

---

## Liu et al. — lost in the middle, U-shaped positional attention {#lost-in-the-middle}

Source: https://arxiv.org/abs/2307.03172
Extracted: 2026-04-23
Finding: Liu, Lin, Hewitt, Paranjape, Bevilacqua, Petroni, and Liang (TACL 2023) measure retrieval accuracy when the position of the relevant information is varied within the input context. Performance is highest when the relevant content sits at the very beginning or the very end of the input, and degrades substantially when it sits in the middle, even for models advertised as long-context. The effect is a U-shaped attention curve, not a linear decay, and it holds across both multi-document question answering and key-value retrieval. This validates treating early positions as high-salience real estate for the most important rules, and warns that content buried in the middle of a long instruction file is attended to less reliably regardless of how the middle is formatted.

---

## Purpura et al. — MOSAIC, compliance varies with constraint type, quantity, and position {#mosaic-primacy-recency}

Source: https://arxiv.org/abs/2601.18554
Extracted: 2026-04-23
Finding: Purpura, Wang, Badyal, Beaufrand, and Faulkner (EACL 2026) introduce MOSAIC, a benchmark that generates prompts containing up to 20 application-oriented generation constraints and measures per-constraint compliance independently from overall task success. Across five evaluated model families, instruction compliance is not monolithic: it varies significantly with constraint type, constraint count, and constraint position within the prompt. The analysis identifies distinct primacy and recency effects, and the magnitude and direction of these biases are model-specific rather than universal. This supports the rule that position in an instruction file is a priority signal, but nuances it: which end of the file is "strongest" is not fixed across models, so a convention built purely on "top of file wins" is brittle for a model-agnostic workflow.

---

## Zeng et al. — constraint order changes compliance even when content is identical {#order-matters-constraints}

Source: https://arxiv.org/abs/2502.17204
Extracted: 2026-04-23
Finding: Zeng, He, Ren, Liang, Xiao, Zhou, Sun, and Yu directly perturb the order of constraints in multi-constraint instructions while holding content constant and measure how much performance fluctuates. Models show dramatic performance swings purely from reordering, and the effect generalises across architectures and parameter counts. Their attention analysis attributes the effect to how attention distributes over constraints at different positions, not to any content-level difference. The specific finding that a "hard-to-easy" ordering outperforms the reverse is a secondary recommendation; the primary, more portable finding is that constraint order is a first-class variable that silently changes compliance. This supports treating section ordering and rule ordering inside instruction files as a deliberate design decision rather than incidental.

---

## Zhou et al. — IFEval, verifiable instructions over abstract ones {#ifeval-verifiable-instructions}

Source: https://arxiv.org/abs/2311.07911
Extracted: 2026-04-23
Finding: Zhou, Lu, Mishra, Brahma, Basu, Luan, Zhou, and Hou (Google, 2023) introduce IFEval, which evaluates instruction-following using 25 categories of "verifiable instructions" such as "write in more than 400 words" or "mention the keyword AI at least 3 times." The benchmark's design rationale is explicit: human evaluation is slow and unreproducible, and LLM-as-judge evaluation inherits the evaluator's biases, so the benchmark restricts itself to instructions whose compliance can be checked mechanically. The surviving instruction set is dominated by concrete, action-specifying constraints rather than abstract quality goals, because abstract goals cannot be verified. This indirectly supports the "concrete actions over abstract goals" authoring rule: the instructions that are cleanly measurable at eval time are also the instructions that are least ambiguous at generation time. It does not, on its own, prove that concrete instructions are followed more reliably than abstract ones when both are in play; it shows that the field's main measurement apparatus was built around verifiable-and-concrete instructions.

---

## Anthropic Claude 4 prompting guidance — positive framing over negative prohibitions {#anthropic-positive-framing}

Source: https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices
Extracted: 2026-04-23
Finding: Anthropic's official Claude 4 prompting guidance recommends giving the model a positive specification of the desired behaviour rather than a prohibition. The canonical example is replacing "Do not use markdown in your response" with "Your response should be composed of smoothly flowing prose paragraphs." The stated rationale is that explicit positive instructions produce more consistent behaviour than negations. The guidance also recommends being explicit and specific about desired output rather than relying on the model to infer intent from a short instruction. This directly supports two authoring rules: negative rules should be paired with a positive alternative, and concrete actions should be preferred over abstract goals. It is a first-party vendor recommendation for a specific model family rather than an academic result, so the strength of the claim is "the model provider recommends this pattern," not "this pattern has been independently benchmarked."

---

## Gap — short lines, CAPS emphasis, no third-person self-reference {#unsupported-format-rules}

Source: n/a
Extracted: 2026-04-23
Finding: We could not find primary-source evidence that directly validates or refutes three specific authoring rules. First, "short lines are attended to more reliably than long lines" as a formatting claim at the line level: the adjacent findings are about long-context degradation over thousands of tokens (Liu et al.) and about constraint count (Purpura et al., IFScale), not about per-line length inside a short instruction file. Second, the use of CAPS on opening verbs (ALWAYS, ASK, NEVER) as a generation-time salience signal for unconditional rules: no public benchmark we found isolates the effect of casing on a leading verb in instruction text. Third, "no third-person self-reference in agent-facing text": we found no study comparing compliance on imperative second-person instructions versus third-person descriptive instructions for the same rule. These three rules are internal craft conventions at present, not claims backed by primary-source evidence.

---
