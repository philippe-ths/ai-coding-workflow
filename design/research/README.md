# Research

Primary-source notes that back the reasoning in `design/decisions/`.

## Purpose

Research files hold extracted findings with stable anchor IDs.
Decision files cite findings by file and anchor.
This separates "what the source says" from "how we apply it."

## Active research files

- `token-efficiency-in-agentic-workflows.md`: context rot, instruction-compliance decay, thinking effort cost curves, RLHF length bias, prompt caching structure.
- `prompt-engineering.md`: positional attention, constraint ordering, verifiable-instruction design, positive-framing guidance, gaps for formatting craft conventions.
- `tokenization.md`: BPE, tokenizer pathologies (rare words, casing, whitespace), prompt format sensitivity, digit tokenization, glitch tokens.
- `spec-driven-development.md`: measured impact of repo-level context files, content study of real AGENTS.md files, GitHub Spec Kit methodology, Anthropic's Claude Code loop, Kent Beck on augmented coding, METR RCT on unstructured AI tooling.
- `skills.md`: progressive-disclosure model, description-drives-triggering, on-demand loading savings, context-dilution failure mode, general agent-interface design.
- `subagents.md`: measured gains from parallel subagents, context-isolation as a first-party feature, briefing requirements, Cognition's counterpoint on shared context, multi-agent failure taxonomy.
- `deterministic-enforcement.md`: prompt-level safety inconsistency, long-context safety degradation, instruction-following instability, external control-flow enforcement, programmable runtime rails, defense-in-depth, OS-level sandboxing.
- `evaluation-methodology.md`: LLM-as-judge biases (position, verbosity, self-preference), self-recognition causal mechanism, criteria drift, McNemar's paired test, multiple-comparisons correction, G-Eval replication of judge bias.

## Citation convention

**Anchor format in research files:**

```markdown
## Finding title {#anchor-id}

Source: <URL>
Extracted: YYYY-MM-DD
Finding: ...
```

**Citation format in decision files:**

```markdown
(See `design/research/token-efficiency-in-agentic-workflows.md#anchor-id`.)
```

Citation paths are repo-relative.
Broken citations are detectable by grep.
Every claim in a decision file that originates from research must carry a citation.
Inline rationale in `ai-workflow.md` is unchanged in form: still `(Why: ...)` for judgment-calling rules.
