# Review Taxonomy — AI Workflow Design Decisions

Covers the classification systems for reviewing `ai-workflow.md`: identifying structural problems (cross-contamination), and determining the correct enforcement mechanism and home for each line (enforcement / placement).

## Cross-Contamination Categories

When reviewing the file for structural problems, classify each line as one of:

- **OK.** Line is in the right place.
- **Cross-contaminated.** Content type does not match the section's purpose (e.g. a rule in the preamble, a principle in a workflow step).
- **Redundant.** The same rule is stated in multiple places.
- **Misplaced.** The line belongs in a different specific section (e.g. a human responsibility in a workflow step).
- **Candidate to move.** The line could be offloaded to a reference section with a pointer left behind.

## Enforcement / Placement Categories

When reviewing a line for its optimal enforcement mechanism and home, classify it as one of:

- **Global rule.** Correct candidate for `ai-workflow.md`, always in context, needed across all phases and tasks.
- **Bright line rule.** Machine-checkable boundary; correct candidate for deterministic enforcement in `.ai-policy/` hooks. Keep the advisory form once in `ai-workflow.md`; the hook enforces it.
- **Dynamic rule.** Condition-specific; correct candidate for extraction to a `workflow/` just-in-time file loaded on demand. A section qualifies when it activates under a specific identifiable condition, is self-contained, and is not needed during the majority of sessions.
- **Human-owned rule.** Describes human behaviour or responsibility; belongs in "The Human is Responsible For" or as an explicit numbered checkpoint, not in agent instruction flow.
- **Advisory redundancy.** An advisory statement that duplicates a rule already fully enforced deterministically by `.ai-policy/`; candidate for removal or reduction to a single short pointer. Distinct from the Redundant cross-contamination category, which covers duplication within the advisory layer itself.
- **Candidate to remove.** The agent could infer this from the codebase or task context; does not need to be stated explicitly; consuming context budget without adding compliance value.

**Note on cluster detection.**
The Enforcement / Placement categories apply per line, but clusters of Global rules around the same topic are a signal the topic deserves its own reference section. When four or more Global rules share a context, flag the cluster as a whole rather than classifying each line individually.
