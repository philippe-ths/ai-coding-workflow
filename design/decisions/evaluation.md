# Evaluation

Covers the periodic review process: when to run it, the minimum-data gate, how to analyse telemetry and baseline results, and how to produce and approve classified workflow improvement proposals.

## Periodic review process

The periodic review is calendar-driven, not per-task.
It analyses accumulated telemetry and baseline results, then produces classified workflow improvement proposals.

The per-task workflow lives in `ai-workflow.md`.
This document is a separate process invoked outside that loop.

### Why this is not a workflow step

The per-task workflow runs on every change.
Running a meta-analysis of telemetry on every change is wasteful and adds noise to normal development.
Periodic review belongs on a calendar cadence: monthly, or whenever enough new tagged data has accumulated.

### When to run a review

- **Calendar trigger.** Monthly, or after a workflow version bump that introduces measurable change.
- **Data trigger.** When accumulated telemetry crosses the minimum-data gate defined below.
- **Human triggers the review explicitly.** The agent does not start one autonomously.

### Minimum-data gate

Do not produce proposals unless **all** of the following hold:

- At least two workflow versions have baseline harness data on disk under `telemetry/data/baseline/<workflow_version>/`.
- At least 20 real Claude Code sessions per version are present in Loki for the corresponding `workflow_version` label.
- The baseline runs cover the same set of tasks across versions, so paired McNemar comparison is possible.
- The `ruleset_hash` is consistent within each version, so the data measures one ruleset state, not a mid-flight change.

The specific n=20 session threshold is a practical floor rather than a figure traceable to one canonical paper; the underlying principle is that single-test p-values become unreliable at small sample sizes and when many tests run in parallel.
(See `design/research/evaluation-methodology.md#multiple-comparisons-correction` for the family-wise error rate inflating to ~64% when running 20 independent tests at alpha=0.05.)

If any condition fails, do not produce proposals. Report instead:

- Which condition is not met.
- The current data counts (versions, sessions, tasks, runs).
- The earliest date the gate could be expected to pass given current capture rate.

A thin-data review must end at this point. Do not paper over the gap.

### Inputs the review reads

- **Baseline harness JSONs** at `telemetry/data/baseline/<workflow_version>/<ruleset_hash>/<task_id>/<run_id>.json`. Schema in `docs/telemetry-schema.md`.
- **Loki session logs** for Claude Code sessions tagged with `workflow_version` and `ruleset_hash`. Query via the Loki HTTP API or via the Grafana stack in `telemetry/`.
- **Prometheus aggregates** for the same labels. Query via PromQL.
- **Sampled transcripts** if retained by the harness or by separate session capture.
- **observations/observed-ai-failings.md** for human-recorded qualitative patterns. Use only as supplementary evidence; this file pre-dates the data loop and represents intuition-era observations.

### Analyses to run

For pass/fail comparison between two workflow versions:

- Run `python scripts/compare-versions.py <version_a> <version_b>` to produce per-task `pass^k`, aggregate `pass^k`, McNemar's test on paired pass/fail outcomes, and mean/median deltas on duration, cost, tokens, and fix cycles.
- Treat McNemar p < 0.05 as a candidate signal, not a conclusion. Confirm with at least one of: a transcript snippet, a `prompt.id` cluster, or a clear continuous-metric delta in the same period.

(See `design/research/evaluation-methodology.md#dietterich-mcnemar-paired-test` for the canonical justification of McNemar's test as the paired comparison for classifier pass/fail outcomes, including the demonstration that two unpaired tests have unacceptable Type I error rates for this design.)

For event-level signals from telemetry:

- Scan `tool_decision` events for elevated rejection rates by tool name. Group by workflow step where determinable.
- Scan `fix_cycles` distribution for outliers; cluster by task and ruleset to see whether the spike concentrates on one rule or one task type.
- Scan rejected tool calls grouped by `prompt.id` to find points where the agent attempted an action the workflow disallows.

For transcript-level signals:

- Use LLM-as-judge on a sampled subset of transcripts.
- Each judge call must answer one focused question (for example: "did the agent appear to revisit Step 5 because Step 6 failed?") and must cite the snippet supporting its answer.
- Treat LLM-judge output as a hypothesis. A judge claim that cannot be backed by a quoted transcript snippet is not evidence.

(See `design/research/evaluation-methodology.md#zheng-llm-judge-biases` for measured position bias, verbosity bias, and self-enhancement bias in LLM judges; `#panickssery-self-preference` for the causal link between self-recognition capability and self-preference magnitude; `#shankar-criteria-drift` for how judge criteria drift over time and why LLM-graded output is fragile without human validation; `#g-eval-llm-bias` for independent replication of judge bias toward LLM-generated text.)

### Proposal output format

Every proposal must include all of the following fields. A proposal missing any field is not eligible for review.

```
### Proposal <N>: <short title>

- Classification: one of hook, skill, rule, step, multi
- Problem observed:
  <One paragraph. Concrete enough to test.>
- Evidence:
  <Specific numbers, prompt.ids, transcript snippets, or McNemar results.
   Cite at least one quantitative source AND one qualitative source if both exist.
   If only qualitative evidence exists, label the proposal "qualitative-only".>
- Proposed change:
  <The specific modification to the workflow stack. Name the file or surface that would change.>
- Affected surface:
  <Exact file path or hook name. For multi-surface changes, list every surface and order them by required edit sequence.>
- Risks:
  <What could regress. What scenarios the proposed change does not cover.>
- Rollback plan:
  <The exact sequence to revert if the change makes things worse.>
```

### Classifications

- **hook** — change to scripts under `.ai-policy/hooks/`, `.githooks/`, `.claude/settings.json` hooks, `.codex/hooks.json`, or `.gemini/settings.json` BeforeTool config.
- **skill** — change to a file under `.agents/skills/` or `.claude/skills/`. Skills must be edited in both directories together.
- **rule** — change to text inside `ai-workflow.md` (a workflow rule, validation requirement, scope-control item, or boundary rule), without changing the numbered step list.
- **step** — change to the numbered step list in `ai-workflow.md` (adding, removing, reordering, or splitting a step).
- **multi** — any proposal that touches more than one of the above surfaces. Multi proposals must list every surface and an explicit edit sequence.

### Disqualifying conditions

Reject a proposal at review if any apply:

- Evidence comes from a single session.
- Quantitative evidence relies on data below the minimum-data gate.
- The proposal cannot name a specific file, hook, or skill it would modify.
- An LLM-judge claim has no quoted transcript snippet.
- The pattern can be explained by a known unrelated change in the same period.
- The proposal restates an existing rule without adding new evidence that the rule is failing.
- No rollback plan is stated, or the rollback plan is not specific enough to execute.
- The proposed change is vague (for example: "improve scope control" without naming a file or rule).

### Approval workflow

1. The agent produces the proposal batch in the format above and presents it to the human in a single document.
2. The human reviews each proposal individually and accepts, rejects, or asks for revision.
3. For each accepted proposal, the agent loads the `aiw-issue-creation` skill and creates one GitHub issue per proposal.
4. Implementation of each accepted proposal goes through the standard per-task workflow defined in `ai-workflow.md`.
5. The review document itself is archived under `observations/workflow-reviews/<date>.md` so future reviews can reference prior findings.

### Worked examples

The first executed worked example is `observations/workflow-reviews/2026-04-19.md`. It demonstrates the gate refusing on quantitative thinness and produces one illustrative qualitative-only proposal that would itself be rejected under the disqualifying conditions.

## Line review taxonomies

The proposal classification above (hook, skill, rule, step, multi) classifies a proposed change.
The taxonomies below classify lines within `ai-workflow.md` during a line-by-line audit of the file itself.
Section type definitions (preamble, First Principles, workflow, reference, boundary, human responsibilities) are in `design/decisions/authoring.md` under **ai-workflow.md**.

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
