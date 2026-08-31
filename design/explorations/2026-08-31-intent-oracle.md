# Intent Oracle: A Second Oracle for Desirability

Descends from `2026-08-31-dark-factory.md`.
Selects one of the four improvements that exploration contains, and works it to the point where an implementation plan could be written.

## Status

This is an exploration, not a decision.
Nothing here has been implemented.
It records a design discussion held on 2026-08-31, immediately after the dark-factory discussion.
Where the human made a choice during the discussion, it is marked as a choice taken rather than a recommendation.
Choices taken here are still subject to the normal plan review; recording them is not approval to build.

## Where This Sits

The dark-factory exploration contains four separable improvements, not one.

Invert the review model, so the human owns desirability and the machine owns quality.
Give the workflow a second oracle, for intent, since it has one only for correctness.
Make the workflow fit non-deterministic systems, whose evidence cannot be a single passing run.
Move the unit of governance from the task to the project, which is where mess and conformity live.

The second was chosen as the one to plan first.

The reason is stated in the dark-factory exploration itself.
Every gate removed was removed by finding something else to answer its question.
Inverting the review model is blocked on its own preconditions, of which the intent oracle is one.
Escaping a mess has no oracle other than the north-star, so it is blocked on the same thing.
Fitting non-deterministic systems is orthogonal, changing how evidence is judged rather than who judges it, so it can proceed on its own timeline without blocking anything.

## The Asymmetry

The workflow's oracle structure is asymmetric, and the asymmetry is total rather than partial.

For correctness it has four things.
A trust hierarchy saying where truth comes from.
A sourcing protocol for when truth is missing.
Storage and provenance rules.
Modality-specific oracle rules.

For intent it has none of those.
Not a weak version, and not an implicit one.
Every intent question is resolved the same way, by interrupting the human.

This is the mechanical reason the human is pinned at low altitude.
It is not a flaw in how review is designed.
It is a missing oracle, and review design is downstream of it.

## The Design

The intent oracle needs the same four parts as the correctness oracle.
The substance is in the first.

### A trust hierarchy for intent

Correctness truth is ranked by origin, with real observed output above values the agent invented.
Intent truth ranks the same way.

1. A refusal the human actually made, in a situation on the record.
2. A refusal the human stated in the abstract.
3. A preference the human stated.
4. An intention or aspiration.
5. Anything the agent inferred from the code.

Rank 1 is the only rung with real authority.
This is why the dark-factory exploration insists that refusals decide and intentions do not.

"Fast and simple" sits at rank 4 and collapses no choice.
"Better to do nothing than the wrong thing" is a rank 1 or 2 refusal.
It decides whether to degrade or fail loudly, whether to auto-apply or ask, and whether to guess a format or reject it.

The hierarchy is what stops the north-star drifting into a mission statement.
It is the same job the correctness hierarchy does in stopping fixtures drifting into invented values.

### A sourcing protocol

Today, missing intent means interrupt the human.

Under this change it means consult the north-star, then the work's own stated intent, then interrupt.

The interruption is not a failure of the oracle.
It is the oracle's input.
The human's answer is a rank 1 refusal, and the skill's update path is where it lands.

### Storage and provenance

The north-star is durable and per-repository.
It belongs in the `authored_in_target` class of `install-manifest.json`, alongside `project-context.md` and `project-checks.md`, which are the two existing artifacts of the same kind and each owned by a skill.

Each entry carries the decisions it was derived from, so its rank is visible and it can be retested later.
Provenance here is not bookkeeping.
It is what the trust hierarchy is checking.

### Modality-specific rules

New and Improve are almost entirely intent-oracle work.
Fix barely touches it.

This is also where the dark-factory exploration's escape-a-mess gap gets a home.
That work has no correctness oracle by construction, because current behaviour is the thing being escaped.
The intent oracle is the only oracle it can have.
The modality is not in scope here, but the intent oracle is its precondition, which is worth knowing while the oracle is being shaped.

## Choices Taken in the Discussion

The improvement to plan first is the intent oracle.

The north-star is an authored artifact, not a derived one.
The human writes `north-star.md`; a skill guides authoring and updating it.
No correction-capture machinery is built.

The reason for rejecting capture machinery is the repository's own history.
The hard part is not gathering corrections.
It is producing a statement that survives the test the dark-factory exploration sets for it, which is a reading-and-judgment act rather than a pipeline.
This repository has already built and deleted one telemetry stack that ran ahead of the question it was meant to answer.
Capture should be earned by an authored north-star visibly failing to keep up.

The north-star is consulted at two points.
`aiw-planning` consults it when weighing acceptable options, and records in the plan which option it chose and on which entry.
The stop-to-ask rule in `ai-workflow.md` consults it before interrupting the human.

Those two points were chosen because they are where the interrupting question originates.
The question is "which of these two acceptable options do you want", and the dark-factory exploration identifies it as the source of most remaining interruptions.
It does not live in the Ask First list.
Ask First is about risk and irreversibility, which is a different thing and stays with the human.

Plan time alone was rejected because it would leave the mid-implementation interruption unanswered, which is the oracle's own stated target.
Full integration across planning, ground truth, verification, and issue creation was rejected because it commits five skills to an artifact with no track record.

## What Would Ship

`north-star.md`, an authored per-repository artifact.

`aiw-north-star`, the skill owning its authoring and update, parallel to how `aiw-project-context-management` owns `project-context.md`.
It carries the trust hierarchy, the authoring procedure, the altitude test, and the predictive test.

Two consumption points, in `aiw-planning` and in the stop-to-ask rule.

### The brief collapses into the plan

The dark-factory exploration wants an ephemeral per-work brief holding refusals specific to one piece of work, dying with the work.

The plan is already that artifact.
It is per-work, ephemeral, authored before implementation, and owned by `aiw-planning`.

Making the brief a section of the plan rather than a new artifact gives the three-layer design with two artifacts, and puts the brief where the planning skill can already act on it.
This was a recommendation rather than a choice put to the human, because it collapses a layer rather than choosing between options.

## How Success Would Be Measured

Two numbers, and the second matters more.

Hits, meaning interruptions the north-star answered that the human would otherwise have been asked.
This is the value.

Misses, meaning decisions it made that the human overruled.
A north-star that decides confidently and wrongly is worse than none, because under a streamed factory it would decide unattended.

Before either, the gate the dark-factory exploration sets for itself.
Take ten decisions the human actually made and check whether the draft predicts them.

### The corpus exists

Checked on 2026-08-31.
`observations/observed-ai-failings.md` holds 29 entries.
The Claude Code memory directory for this repository holds 7 feedback entries.
`observations/workflow-reviews/` holds 2 archived reviews.
`design/decisions/` holds 8 concern-scoped rationale files.
The repository has upwards of 240 merged pull requests.

The predictive test can therefore run against the first draft rather than waiting for material to accumulate.

### The honesty constraint on that test

The corpus holds corrections about how the agent should work, not about what a product should be.

For this repository those coincide, because its product is its process stance.
For a target repository they do not.

Whatever passes here validates something narrower than what would ship.
That limitation belongs in the skill, rather than being left for a future reader to discover.

## Explicitly Out of Scope

Named so the scope is visible rather than assumed.

Removing the Build and Test gates.
The refuting reviewer.
Moving work out of the main context.
Observability of a running stream.
The work-in-progress limit.
Project health measures.
The escape-a-mess modality.
The non-determinism rework of the evidence hierarchy.

Inverting the review model is the destination.
This is its precondition, not a first instalment of it.

## Footprint

Beyond the three files, the change reaches further than it looks.

A minor version bump in `ai-workflow.md` with its matching `CHANGELOG.md` entry.
A `project-context.md` version bump.
Classification of both new files in `install-manifest.json`.
An update to the documented skill set that `scripts/check-prose-integrity.sh` enforces.
The new skill in both `.agents/skills/` and `.claude/skills/`, since parity is checked.

## Open Questions

Whether one north-star serves a repository, or whether a large repository needs several scoped to areas.
Whether `aiw-init` should report a north-star that has gone unused or unmissed, which would be its first real sensor.
Whether the predictive test is a one-time authoring gate or a recurring check.
How an entry is retired when the human's taste changes, given that provenance ties entries to past decisions.

## Sources

The framing, the four trees, and every claim attributed to the dark-factory discussion come from `design/explorations/2026-08-31-dark-factory.md`.
The corpus counts were measured in this repository on 2026-08-31.
No external sources were consulted for this exploration.
