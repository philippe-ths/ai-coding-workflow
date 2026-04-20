# Workflow Review — 2026-04-19 (worked example)

This is the first worked example produced under the periodic review process defined in `workflow-review.md`.
It runs the process against the data on disk as of 2026-04-19.

## Minimum-data gate result

**Gate not met.** This review does not produce binding proposals. The illustrative proposal below demonstrates the format only; it would itself be rejected under the disqualifying conditions.

| Condition | Required | Observed | Met? |
|---|---|---|---|
| Workflow versions with baseline data | ≥ 2 | 1 (`2.9.0`) | No |
| Real Claude Code sessions per version in Loki | ≥ 20 | 0 (data dir empty; no sessions captured to disk) | No |
| Same task set across versions | yes | n/a (only one version on disk) | No |
| Consistent `ruleset_hash` within each version | yes | yes for `2.9.0` (`b5bbce97`), but irrelevant under the other failures | Pass for that version |

**Earliest date the gate could pass.** When at least one further workflow version has shipped *and* at least 20 real Claude Code sessions have accumulated in Loki for each of those versions. With no live capture currently retained in the repo's data directory, this is not achievable today and depends on the maintainer running tagged sessions.

## Quantitative evidence available right now

- 6 baseline JSONs for `workflow_version=2.9.0`, `ruleset_hash=b5bbce97`, all from the `mock` agent (3 tasks × 2 runs).
- 0 real Claude Code sessions captured under `telemetry/data/`.
- `scripts/compare-versions.py` cannot run a paired comparison because there is only one version on disk.

No quantitative finding can be drawn from this state.

## Illustrative qualitative-only proposal (format demonstration)

This proposal is **not for issue creation**. It demonstrates the proposal format using qualitative evidence from `observations/observed-ai-failings.md`.

### Proposal 1 (illustrative): scope drift during conflict resolution

- **Classification:** `skill`
- **Problem observed:**
  Multiple `observations/observed-ai-failings.md` entries describe the agent silently expanding scope while resolving cherry-pick or merge conflicts — folding adjacent fixes into the resolution commit where review attention is lower than for a normal feature commit.
- **Evidence:**
  Qualitative-only. Cited entry: Entry 20 (cherry-pick conflict scope drift). Pattern is consistent with general scope-control risks already noted in `ai-workflow.md` Scope Control section. No quantitative data because the minimum-data gate is not met.
- **Proposed change:**
  Add a short subsection in the existing `aiw-failure-analysis` skill (or a small new skill `aiw-conflict-resolution`) defining a checklist for conflict-resolution commits: list every file touched, list every change beyond the conflict markers, name the original task, and confirm that no unrelated change crept in.
- **Affected surface:**
  `.claude/skills/aiw-failure-analysis/SKILL.md` and `.agents/skills/aiw-failure-analysis/SKILL.md` — both must change together to preserve cross-platform parity.
- **Risks:**
  Adds checklist friction to the conflict-resolution path. May produce false-positive scope-drift warnings for legitimate adjacent fixes. Does not catch scope drift outside conflict resolution.
- **Rollback plan:**
  `git revert` the commit that adds the subsection. No config rollback needed because this is a documentation-only change.

This proposal would be rejected under the disqualifying conditions because the evidence is qualitative-only AND the minimum-data gate is not met. It is included here solely to demonstrate the format.

## Outcome

- No proposals submitted for issue creation.
- No workflow stack changes recommended.
- Action required: continue accumulating telemetry and baseline data. Re-run this review once the gate can pass.
