# Authoring

## Intro

This file defines writing conventions for files in this repository.
It covers shared base rules that apply across all file types, plus per-section rules for each file type in the system.

Read this file when authoring or editing any markdown file in the repository.
Read this file when authoring or editing shell scripts in `.githooks/` or `.ai-policy/`.
Read this file when reviewing a change that modifies any of the above.

The file is read during maintenance, not during normal task execution.
Agents performing a coding task do not load this file into context.

## Base rules

These rules apply to every file type below unless a section rule explicitly overrides.
Rules that carry a `design/research/` citation have primary-source backing.
Rules without a citation are internal craft conventions without published evidence; treat them as defaults and revise if measurement contradicts them.

**One sentence per line.**
Every line contains exactly one sentence.

**No em-dashes.**

**Writing style.**
Every line is a direct instruction or a direct statement of fact.
Use imperative mood: "Do X", "Do not do X", "Flag this to the human."
Do not use passive voice: "The plan should be reviewed" is weaker than "Wait for the human to review the plan."
When there is a conditional, put the condition first: "If X, do Y."
Do not hedge: avoid "consider", "you might want to", "it is generally a good idea to."
The file instructs.

**Ration rationale.**
Do not include rationale for bright-line mechanical rules where the instruction is unambiguous on its own.
Include inline rationale for a rule only when all three criteria are met: the rule requires a judgment call, an agent could comply with the literal wording while violating the intent, and understanding the why would materially change how the agent applies the rule in ambiguous cases.
Use the format: rule sentence on its own line, then "(Why: rationale.)" on the next line or in a parenthetical on the same line.
Every rationale line consumes tokens that compete with the actual task, so each one must earn its place.
(See `design/research/token-efficiency-in-agentic-workflows.md#chroma-context-rot` and `#ifscale-instruction-compliance-decay`.)

**Negative rules need a positive alternative.**
A rule that only says "Do not do X" leaves the agent guessing what to do instead.
Where possible, pair it with the correct action: "Do not add logging for trivial operations" is fine because the alternative is obvious (do nothing). "Do not use console.log" is incomplete without "Use the project logger instead."
(See `design/research/prompt-engineering.md#anthropic-positive-framing`.)

**No third-person self-reference in agent-facing text.**
In instruction text, use second-person imperative voice.
Do not refer to the agent in third person: "the agent should", "the agent's expectations", "causes the agent to."
Third person is acceptable in metadata (skill frontmatter descriptions) and in sections that describe human responsibilities.

**Concrete over abstract.**
Prefer concrete actions over abstract goals.
"Run the full test suite" over "Ensure adequate test coverage."
"Flag the mismatch to the human" over "Communicate discrepancies appropriately."
Abstract instructions give room to interpret, which means room to get it wrong.
(See `design/research/prompt-engineering.md#ifeval-verifiable-instructions`.)

**Keep lines short.**
If a line needs a subordinate clause to make sense, it is probably two rules and should be split.
Long lines are harder for the model to attend to and easier to partially skip.

**Emphasis formatting.**
Do not use bold, caps, or exclamation marks as a general priority signal across a file.
Position in the file is a priority signal: the first and last positions in a long input are attended to most reliably, and content in the middle degrades.
(See `design/research/prompt-engineering.md#lost-in-the-middle`.)
Which of first or last is strongest is model-specific, so do not rely on any single position; place the most important rules at the start and reinforce unconditional rules in boundary-rule form near the end.
(See `design/research/prompt-engineering.md#mosaic-primacy-recency`.)
Exception: apply CAPS to the opening action verb in boundary rule bullets only (ALWAYS, ASK, NEVER).
This targets generation-time salience for unconditional rules, not abstract priority.
Do not extend caps emphasis to reference section rules or workflow steps.
If emphasis is used broadly, it loses its salience effect and adds noise tokens.

## Section rules

### ai-workflow.md

Written for an AI coding agent.
The human does not need to read it during a task.
The human reads it when maintaining or updating the file.

The "Human is Responsible For" section is also written for the AI agent.
It tells the agent what it cannot do and must leave to the human.

The file is organised into six distinct section types.
Each section type has a single responsibility.

**Preamble.**
Context only.
What this file is, who it is for.
Contains no rules or principles.

**First Principles.**
The governing truths.
Keep this section as short as possible.
Every line must earn its place by being genuinely foundational.
The workflow must be model-agnostic and repo-agnostic.

**Workflow.**
The ordered sequence of steps for every task.
Each step describes what happens and when, not how to do it in detail.
Detailed rules belong in reference sections.
The workflow points to reference sections rather than inlining their content.
Human checkpoints are explicit numbered steps.

**Reference sections.**
The detailed "how" for specific topics: planning, implementation, scope, validation, failure analysis, logging, command approval, GitHub workflow, sub-issue handling.
These do the heavy lifting.
Each reference section owns its topic.
Rules about that topic live here, not scattered across the workflow or boundary sections.

**Boundary rules.**
Global, context-free rules that apply regardless of which step or topic is active.
Rules that do not fit into reference sections.
Three tiers: Always Do, Ask First, Never Do.

**The Human is Responsible For.**
What the AI cannot do.
This exists so the agent knows where to stop and hand off.

### project-context.md

Written for an AI coding agent.
The human does not need to read it during a task.
The human reads it when maintaining or updating the file.

The project context records current implementation truth.
The project could theoretically be recreated, in broad terms, from this file.
The project context is a factual reference, not a roadmap.
The project context helps an AI agent orient quickly before planning changes.
(See `design/research/spec-driven-development.md#agents-md-runtime-tokens` for measured cost impact and `#agent-readmes-content-study` for the factual-not-aspirational framing.)

**Content rules.**
Prefer present-tense facts over future intentions.
Do not duplicate the same fact in multiple sections.
If a fact is uncertain, mark it as unknown instead of guessing.
Use the current codebase as the source of facts over specs or docs.
If issue text conflicts with the codebase, document the codebase truth and note the mismatch.
State constraints as enforceable facts, not advice.
Keep names aligned with real module, path, and entity names.

**Section shape.**
Use stable sections so agents can parse the file quickly.
Include Product Summary, Domain Concepts, Scope, Important Constraints, Architecture Summary, Key Dependencies, Project Structure, Testing Overview, Known tools available, and Human notes.
Remove empty sections only when the project has no reliable information for that section.
Use one bullet per fact in list sections.

**Maintenance.**
Update the context file when routes, schema, sync rules, persistence, or provider behavior changes.
Update the context file when build, runtime, or dependency boundaries change.
During reviews, remove stale lines instead of accumulating historical notes.
Update outdated terms when the codebase is renamed or refactored.
Keep the file under 300 lines.
If the file approaches 300 lines, merge overlapping facts and remove low-value detail.

### Skill files (SKILL.md)

Each skill is self-contained.
Skills load on demand, only when triggered by the workflow or by the agent's judgment.
The skill body is written for the AI agent in imperative second-person voice.
The base rules apply.

**Frontmatter description drives triggering.**
The frontmatter description is the only part of the skill always present in the system prompt; the body loads only if the agent decides the skill applies.
Write the description in third person.
State both what the skill does and when to use it, with concrete triggers: filenames, command patterns, or task phrases.
Keep descriptions under 1024 characters.
A vague or first-person description causes the wrong skill to be invoked, or none at all.
(See `design/research/skills.md#skill-description-trigger-selection` and `#tool-to-agent-retrieval-context-dilution`.)

**Keep skill bodies under 500 lines.**
Split longer skills into linked files inside the skill directory.
Reference the linked files from the body by filename so the agent reads them on demand rather than up front.
(See `design/research/skills.md#anthropic-agent-skills-progressive-disclosure`.)

### Hooks and policy scripts (.githooks/, .ai-policy/)

These are shell scripts, not markdown.
The base rules apply to in-script comments and accompanying docs; they do not apply to script syntax.

Each script owns a single concern.
If a script grows past a single responsibility, split it.
Validate syntax with `bash -n`; the repository's `project-validation.sh` runs this automatically.

Source `policy.env` rather than hardcoding configuration values.
Keep the set of configuration variables minimal and named for the rule they control, not the script that reads them.

Scripts fail loudly.
Exit non-zero on error.
Print the rule being enforced and the specific condition that failed so the human reading the terminal understands why the action was blocked.

Header comments state the script's single purpose in one sentence.
Do not duplicate the advisory form of a rule in a script; the advisory form lives in `ai-workflow.md`, and the script enforces it.

### Rule files

No dedicated rule files exist in the repository yet.
When they are introduced, add authoring conventions here rather than scattering them across other files.

### Agent entry points (CLAUDE.md, AGENTS.md, GEMINI.md, Copilot configs)

Agent entry points route the agent to `ai-workflow.md` and `project-context.md`.
They do not contain workflow rules; rules belong in `ai-workflow.md`.
Keep entry points short: their job is to point at the right files, not to duplicate content.

### Doc files

Doc files describe technical aspects of the system: how a component works, how to run it, what its inputs and outputs are.
READMEs and setup guides are doc files.

Doc files are written for a human reader first.
The base rules apply with one exception: descriptive prose is acceptable alongside imperative instruction.
One sentence per line still applies so diffs remain reviewable.

State the what and the how.
Defer the why to the matching file in `design/decisions/`.
Link to the decision file rather than restating its reasoning.

### Design files (design/decisions/, design/research/)

Design files record why a decision was made, not how the system currently works.
If a file describes current behaviour, it belongs in docs, not design.

Each decision file covers one concern.
The first line after the H1 states the concern in one sentence.
See `design/README.md` for the current index of concerns.

Design files may contain more prose than other file types because they must carry reasoning.
The base rules still apply without exception, including one sentence per line.

Cite primary sources from `design/research/` rather than restating claims without citation.
When a decision supersedes a prior decision, link the prior decision and state what changed.

Research files hold primary-source notes.
Follow the citation convention in `design/research/README.md`.
