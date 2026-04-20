# Authoring

Covers writing conventions, file structure, and review taxonomy for agent-facing files in this repository.

## Writing rules (apply to all agent-facing files)

**One sentence per line.**
Every line should contain exactly one sentence.

**No em-dashes.**

**Writing style.**
Every line should be a direct instruction or a direct statement of fact.
Use imperative mood: "Do X", "Do not do X", "Flag this to the human."
Do not use passive voice: "The plan should be reviewed" is weaker than "Wait for the human to review the plan."
When there is a conditional, put the condition first: "If X, do Y."
Do not hedge: avoid "consider", "you might want to", "it is generally a good idea to."
The file instructs. It does not teach, persuade, or justify.
Do not include rationale for bright-line mechanical rules where the instruction is unambiguous on its own.
Include inline rationale for a rule only when all three criteria are met: the rule requires a judgment call, an agent could comply with the literal wording while violating the intent, and understanding the why would materially change how the agent applies the rule in ambiguous cases.
Use the format: rule sentence on its own line, then "(Why: rationale.)" on the next line or in a parenthetical on the same line.
Every rationale line consumes tokens that compete with the actual task, so each one must earn its place.

**Negative rules need a positive alternative.**
A rule that only says "Do not do X" leaves the agent guessing what to do instead.
Where possible, pair it with the correct action: "Do not add logging for trivial operations" is fine because the alternative is obvious (do nothing). "Do not use console.log" is incomplete without "Use the project logger instead."

**No third-person self-reference in agent-facing text.**
In instruction text (workflow steps, skill bodies), use second-person imperative voice.
Do not refer to the agent in third person: "the agent should", "the agent's expectations", "causes the agent to."
Third person is acceptable in metadata (skill frontmatter descriptions) and in sections that describe human responsibilities.

**Concrete over abstract.**
Prefer concrete actions over abstract goals.
"Run the full test suite" over "Ensure adequate test coverage."
"Flag the mismatch to the human" over "Communicate discrepancies appropriately."
Abstract instructions give the agent room to interpret, which means room to get it wrong.

**Keep lines short.**
If a line needs a subordinate clause to make sense, it is probably two rules and should be split.
Long lines are harder for the model to attend to and easier to partially skip.

**Emphasis formatting.**
Do not use bold, caps, or exclamation marks as a general priority signal across the file.
Position in the file and placement in First Principles remain the primary priority signals.
Exception: apply CAPS to the opening action verb in boundary rule bullets only (ALWAYS, ASK, NEVER).
This targets generation-time salience for unconditional rules, not abstract priority.
Do not extend caps emphasis to reference section rules or workflow steps.
If emphasis is used broadly, it loses its salience effect and adds noise tokens.

## File structure and audience

### ai-workflow.md

The file is written for an AI coding agent.
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
Each step should describe what happens and when, not how to do it in detail.
Detailed rules belong in reference sections.
The workflow points to reference sections rather than inlining their content.
Human checkpoints are explicit numbered steps.

**Reference sections.**
The detailed "how" for specific topics: planning, implementation, scope, validation, failure analysis, logging, command approval, GitHub workflow, sub-issue handling.
These do the heavy lifting.
Each reference section owns its topic.
Rules about that topic should live here, not scattered across the workflow or boundary sections.

**Boundary rules.**
Global, context-free rules that apply regardless of which step or topic is active.
Rules that don't fit into Reference sections.
Three tiers: Always Do, Ask First, Never Do.

**The Human is Responsible For.**
What the AI cannot do.
This exists so the agent knows where to stop and hand off.

### project-context.md

This document defines maintenance rules for `project-context.md` files.
It is for humans who maintain project context files.
Use these rules when creating or editing a project context file.

#### Core purpose

The project context records current implementation truth.
The project context is a factual reference, not a roadmap.
The project context should help an AI agent orient quickly before planning changes.

#### Base rules

Every line must contain exactly one sentence.
Keep the file short and under 300 lines.
Keep each sentence concrete and specific.
Prefer present-tense facts over future intentions.
Avoid rationale unless it is required for correctness.
Do not duplicate the same rule or fact in multiple sections.
If a fact is uncertain, mark it as unknown instead of guessing.

#### Section shape

Use stable sections so agents can parse the file quickly.
Include Product Summary, Domain Concepts, Scope, Important Constraints, Architecture Summary, Key Dependencies, Project Structure, and Testing Overview.
Remove empty sections only when the project has no reliable information for that section.
Use one bullet per fact in list sections.

#### Content quality

Prefer codebase-confirmed facts over issue or ticket suggestions.
If issue text conflicts with the codebase, document the codebase truth and note the mismatch.
State constraints as enforceable facts, not advice.
Keep names aligned with real module, path, and entity names.
Update outdated terms when the codebase is renamed or refactored.

#### Maintenance

Update the context file when routes, schema, sync rules, persistence, or provider behavior changes.
Update the context file when build, runtime, or dependency boundaries change.
During reviews, remove stale lines instead of accumulating historical notes.
Do not let this file exceed 300 lines.
If the file approaches 300 lines, merge overlapping facts and remove low-value detail.

### Skill files (SKILL.md)

Skill files have no separate authoring conventions beyond the writing rules above.
Each skill is self-contained and loads only when the workflow step that requires it is reached.
Skills are written for the AI agent in the same imperative second-person voice as `ai-workflow.md`.

### Agent entry points (CLAUDE.md, AGENTS.md, GEMINI.md, copilot)

Agent entry points point to `ai-workflow.md` and `project-context.md`.
They should not contain workflow rules; rules belong in `ai-workflow.md`.
Keep entry points short: their job is to route the agent to the right files, not to duplicate content.

## Review taxonomy

Covers the classification systems for reviewing `ai-workflow.md`: identifying structural problems (cross-contamination), and determining the correct enforcement mechanism and home for each line (enforcement / placement).

### Cross-contamination categories

When reviewing the file for structural problems, classify each line as one of:

- **OK.** Line is in the right place.
- **Cross-contaminated.** Content type does not match the section's purpose (e.g. a rule in the preamble, a principle in a workflow step).
- **Redundant.** The same rule is stated in multiple places.
- **Misplaced.** The line belongs in a different specific section (e.g. a human responsibility in a workflow step).
- **Candidate to move.** The line could be offloaded to a reference section with a pointer left behind.

### Enforcement / placement categories

When reviewing a line for its optimal enforcement mechanism and home, classify it as one of:

- **Global rule.** Correct candidate for `ai-workflow.md`, always in context, needed across all phases and tasks.
- **Bright line rule.** Machine-checkable boundary; correct candidate for deterministic enforcement in `.ai-policy/` hooks. Keep the advisory form once in `ai-workflow.md`; the hook enforces it.
- **Dynamic rule.** Condition-specific; correct candidate for extraction to an agent-specific skill loaded on demand. For qualification criteria see `design/decisions/maintenance.md` under **File Splitting**.
- **Human-owned rule.** Describes human behaviour or responsibility; belongs in "The Human is Responsible For" or as an explicit numbered checkpoint, not in agent instruction flow.
- **Advisory redundancy.** An advisory statement that duplicates a rule already fully enforced deterministically by `.ai-policy/`; candidate for removal or reduction to a single short pointer. Distinct from the Redundant cross-contamination category, which covers duplication within the advisory layer itself.
- **Candidate to remove.** The agent could infer this from the codebase or task context; does not need to be stated explicitly; consuming context budget without adding compliance value.

**Note on cluster detection.**
The Enforcement / Placement categories apply per line, but clusters of Global rules around the same topic are a signal the topic deserves its own reference section.
When four or more Global rules share a context, flag the cluster as a whole rather than classifying each line individually.
