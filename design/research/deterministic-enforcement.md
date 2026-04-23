# Deterministic Enforcement

Primary-source notes on why safety-critical rules belong in deterministic enforcement rather than instruction-following, and how defense-in-depth applies to AI agent systems.
See `design/research/README.md` for the citation convention.

---

## Hierarchical safety principles conflict with task goals {#hierarchical-safety-cost-of-compliance}

Source: https://arxiv.org/abs/2506.02357
Extracted: 2026-04-23
Finding: Potham (2025) introduces a lightweight benchmark to evaluate whether an LLM agent upholds a high-level safety principle when a conflicting task instruction is present. Across six evaluated LLMs, the study reports two primary findings: a quantifiable "cost of compliance" where adherence to safety constraints degrades task performance even when solutions that satisfy both exist, and an "illusion of compliance" where high observed adherence often reflects task incompetence rather than principled choice. The authors conclude that current prompt-level hierarchical directives "lack the consistency required for reliable safety governance," i.e. that soft instruction-following is not a sound substitute for mechanical enforcement of bright-line rules.

---

## LongSafety: safety degrades with context length and extra input {#longsafety-long-context-degradation}

Source: https://arxiv.org/abs/2502.16971
Extracted: 2026-04-23
Finding: Lu et al. (2025) introduce LongSafety, a benchmark of 1,543 open-ended long-context safety test cases averaging 5,424 words per context across 7 safety issue categories and 6 task types. Evaluated on 16 representative LLMs, most models achieve safety rates below 55%. The authors report that strong safety performance on short-context inputs does not transfer to long-context tasks, and that both relevant-context insertion and extended input length can exacerbate safety violations. This is direct evidence that relying on instruction-level safety constraints becomes less reliable as the surrounding context grows, independent of the IFScale / context-rot mechanisms previously cited.

---

## LIFBench: instruction-following stability varies across length intervals {#lifbench-instruction-stability}

Source: https://arxiv.org/abs/2411.07037
Extracted: 2026-04-23
Finding: Wu et al. (2024/2025) introduce LIFBench, a benchmark of 2,766 instructions across three long-context scenarios and eleven tasks, with inputs expanded along length, expression, and variables. They evaluate 20 LLMs across six length intervals using a rubric-based automated scorer (LIFEval). The paper's framing and experiments treat instruction-following not just as mean accuracy but as stability — whether a model consistently follows the same instruction under input perturbations. The benchmark exists precisely because existing evaluations "seldom focus on instruction-following in long-context scenarios or stability on different inputs," i.e. the research community treats length-dependent instability as a known, measurable failure mode that a deployment must plan for.

---

## CaMeL: defeating prompt injection by external control-flow enforcement {#camel-control-flow-enforcement}

Source: https://arxiv.org/abs/2503.18813
Extracted: 2026-04-23
Finding: Debenedetti et al. (Google DeepMind / ETH Zurich, 2025) propose CaMeL, a defense that wraps an LLM agent with an external system layer rather than relying on the model to resist prompt injection. CaMeL extracts control and data flows from the trusted user query and executes them in a custom interpreter, so untrusted data retrieved by the LLM cannot alter program flow. Capabilities attached to data values enforce security policies at tool-call time, blocking exfiltration over unauthorized data flows. On AgentDojo, CaMeL solves 77% of tasks with provable security, compared to 84% solved by an undefended system — a small utility cost for a structural guarantee. The architectural point applies directly to enforcement layers for coding agents: security-critical constraints are expressed outside the model as code-level checks on tool invocations, not inside the prompt.

---

## NeMo Guardrails: programmable rails independent of the underlying LLM {#nemo-guardrails-programmable-rails}

Source: https://arxiv.org/abs/2310.10501
Extracted: 2026-04-23
Finding: Rebedea et al. (NVIDIA, EMNLP 2023 Demo) describe NeMo Guardrails, an open-source toolkit for adding programmable "rails" to LLM applications. The paper distinguishes training-time alignment (guardrails baked into the model) from runtime rails that are "user-defined, independent of the underlying LLM, and interpretable." Rails are expressed in a dialogue-management runtime (Colang) so that rule enforcement is decoupled from whether the model happens to follow a prompt. The paper positions rails as complementary to alignment rather than a replacement, consistent with a two-layer model in which model-side training reduces average risk and a deterministic runtime layer enforces the bright-line constraints.

---

## Google SRE — defense in depth through independent layers {#google-sre-defense-in-depth}

Source: https://google.github.io/building-secure-and-reliable-systems/raw/ch08.html
Extracted: 2026-04-23
Finding: Chapter 8 of Google's "Building Secure and Reliable Systems" (Adkins et al., 2020) characterizes resilient systems by designing each layer to be independently resilient, so that a compromise of one layer does not compromise the whole. The chapter emphasizes compartmentalization along clearly defined boundaries, so that isolated functional parts enable complementary defensive behaviors, and uses the Trojan Horse as an example of how a second layer of containment (e.g. a secure courtyard around the gates) would have limited damage after the outer perimeter failed. This is the classical security-engineering justification for stacking pre-commit and pre-push hooks: a bypass of the first layer (e.g. `git commit --no-verify`) is contained by an independent layer at a different point in the workflow.

---

## Anthropic Claude Code — OS-level sandbox as a permission layer {#claude-code-sandbox}

Source: https://www.anthropic.com/engineering/claude-code-sandboxing
Extracted: 2026-04-23
Finding: Anthropic's engineering post on Claude Code sandboxing describes the bash tool running inside an OS-level sandbox built on Linux bubblewrap and macOS Seatbelt. The sandbox enforces two invariants regardless of what the model decides to run: filesystem isolation (reads and writes confined to the working directory; writes outside are blocked) and network isolation (internet access only via a proxy-backed unix domain socket). These constraints apply not just to commands the agent issues directly but also to subprocesses spawned by those commands. In auto-allow mode, sandboxable commands run without prompts; commands that cannot be sandboxed fall back to the normal permission flow. This is a first-party example of the two-layer model: model-side permissions reduce prompting friction inside the safe region, while an OS-level sandbox supplies the deterministic bright-line guarantee that the model cannot revoke by reasoning its way past it.

---
