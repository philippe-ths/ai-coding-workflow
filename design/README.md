# Design

Maintenance documentation for the AI coding workflow repository.

## Decisions

Files in `decisions/` explain the reasoning behind each part of the system.
Find the file for your concern:

| File | Concern |
|---|---|
| `authoring.md` | Writing conventions, file structure, and review taxonomy for agent-facing files |
| `context-economics.md` | Context budget, progressive disclosure, and skill loading |
| `enforcement-layers.md` | The `.ai-policy/` deterministic enforcement system and `.githooks/` git hooks |
| `evaluation.md` | Periodic review process: minimum-data gate, analyses, proposal format, and approval workflow |
| `maintenance.md` | Versioning, CHANGELOG entries, file splitting, and the reusable maintenance prompt |
| `observation-capture.md` | How to record entries in `observations/observed-ai-failings.md` |
| `rule-placement.md` | Where rules belong within `ai-workflow.md`: canonical location and section boundaries |
| `runtime-configuration.md` | Thinking effort defaults, output brevity, prompt caching, and subagent use |
| `ai-workflow-line-by-line.md` | Rationale and source for every line in `ai-workflow.md` |

## Research

Files in `research/` hold primary-source notes that back the reasoning in `decisions/`.
See `research/README.md` for the citation convention.
