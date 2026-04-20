# Research

Primary-source notes that back the reasoning in `design/decisions/`.

## Purpose

Research files hold extracted findings with stable anchor IDs.
Decision files cite findings by file and anchor.
This separates "what the source says" from "how we apply it."

## Active research files

- `token-efficiency-in-agentic-workflows.md` — context rot, instruction-compliance decay, thinking effort cost curves, RLHF length bias, prompt caching structure.

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
