# Spec-Driven Development and AI Workflow Methodology

Primary-source notes on structured workflow approaches for AI coding agents.
See `design/research/README.md` for the citation convention.

---

## AGENTS.md reduces runtime and output tokens {#agents-md-runtime-tokens}

Source: https://arxiv.org/abs/2601.20404
Extracted: 2026-04-23
Finding: Lulla et al. execute AI coding agents on 124 pull requests across 10 repositories under two conditions: with and without a repository-level AGENTS.md file. Presence of AGENTS.md is associated with a 28.64% reduction in median wall-clock runtime and a 16.58% reduction in median output token consumption, with comparable task completion behavior. The authors frame AGENTS.md as a repository-level configuration artifact that shapes agent behavior rather than a general-purpose specification. The study is small (10 repos, 5-page workshop-style paper) and does not isolate which kinds of content in the file produce the benefit, so it supports the claim that a stable project-level instruction file makes agents more efficient but does not tell us which sections matter most.

---

## Content of real agent context files skews functional, not aspirational {#agent-readmes-content-study}

Source: https://arxiv.org/abs/2511.12884
Extracted: 2026-04-23
Finding: Chatlatanagulchai et al. analyze 2,303 agent context files from 1,925 repositories and classify their content against 16 instruction types. Developers overwhelmingly populate these files with functional, codebase-grounded context: implementation details (69.9%), architecture (67.7%), and build/run commands (62.3%). Non-functional concerns like security (14.5%) and performance (14.5%) are rarely specified. The files are not static documentation — they evolve through frequent small additions and behave more like configuration code than prose. This supports treating a project-context file as a factual reference about the current codebase (what exists, how it builds, how it is structured) rather than a roadmap or aspirational spec, and it flags that guardrail content is systematically underrepresented in practice.

---

## Spec Kit positions the spec (not the code) as the primary artifact {#github-spec-kit-methodology}

Source: https://github.com/github/spec-kit
Extracted: 2026-04-23
Finding: GitHub's open-source Spec Kit defines spec-driven development (SDD) as a staged workflow — specification, then technical plan, then small testable tasks — where the specification is treated as the primary artifact and code is a downstream output. The methodology is designed around the premise that AI agents perform better when given a precise "what" and a separate "how" than when given freeform prompts, and it splits those two concerns into separate documents. Spec Kit is a practitioner toolkit with broad industry adoption (docs list 30+ supported AI tools), not a controlled experiment, so it establishes the SDD pattern and its intended mechanism (separating stable intent from flexible implementation) but does not measure outcome improvement over unstructured prompting.

---

## Anthropic's recommended Claude Code loop is ordered and checkpointed {#anthropic-claude-code-best-practices}

Source: https://www.anthropic.com/engineering/claude-code-best-practices
Extracted: 2026-04-23
Finding: Anthropic's engineering guidance for Claude Code describes a recommended multi-step loop — explore the relevant code, produce a plan, implement in small increments, verify, and commit — and explicitly calls out that letting the model skip straight to coding produces worse results than forcing a plan step first. The post recommends a checked-in CLAUDE.md context file and positions test-driven development as "the single strongest pattern for working with agentic coding tools" because each red/green cycle gives the agent unambiguous feedback. The post is first-party prescriptive guidance from the model vendor rather than a controlled study, so it is authoritative about what Anthropic recommends but does not itself measure the effect size of each practice.

---

## Kent Beck on tests as guardrails for non-deterministic agents {#kent-beck-augmented-coding}

Source: https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes
Extracted: 2026-04-23
Finding: Kent Beck argues that "augmented coding" with AI agents does not relax traditional engineering standards — code complexity, test coverage, and maintainability still matter — but shifts which developer skills are leveraged, amplifying vision, task breakdown, and feedback-loop design while deprecating language-level fluency. He characterizes AI agents as "unpredictable genies" that grant wishes in unexpected ways, and argues that test-driven development becomes functionally necessary rather than optional when working with them: the test suite is the mechanism that catches the unexpected interpretations before they compound. This is a named-practitioner position piece, not a measured study, so it supports the argument for TDD and human-defined verification gates as a property of agent non-determinism rather than a quantified effect.

---

## METR RCT: AI tooling slowed experienced developers in a 2025 study {#metr-ai-productivity-rct}

Source: https://arxiv.org/abs/2507.09089
Extracted: 2026-04-23
Finding: Becker et al. ran a randomized controlled trial with 16 experienced open-source developers completing 246 tasks in mature projects they had an average of five years of prior experience on. Tasks were randomly assigned to allow or disallow early-2025 AI tools (primarily Cursor Pro with Claude 3.5/3.7 Sonnet). Developers forecast AI would reduce completion time by 24%; post-hoc they estimated 20% reduction. Measured outcome: AI tooling *increased* completion time by 19%. The authors evaluate 20 candidate explanations and conclude the slowdown is robust to experimental-artifact concerns. The study does not test SDD or structured-workflow approaches specifically — it measures unstructured use of AI tools by experts on codebases they know well. It is a directly relevant caution against assuming AI tooling is productivity-positive by default, and it motivates (but does not itself demonstrate) the claim that structured workflow discipline is needed to convert AI use into net speedup.

---
