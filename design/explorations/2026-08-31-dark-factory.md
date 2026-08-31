# Dark Factory: Human Role, Delegation Economics, and Project Health

Explores moving the human up a level in the workflow, letting Build and Test run without a gate, and the conditions that would make that safe.

## Status

This is an exploration, not a decision.
Nothing here has been implemented and no option has been chosen.
It records a design discussion held on 2026-08-31 so the reasoning is not lost.
Where a claim is measured, the measurement is stated.
Where a claim is argument, it is marked as argument.

## The Question

The current pipeline is Direction (human), then Design, Issue, Plan, Build, Test each with human review, then PR (human).
The human's position is that this is too much review at too low a level.
The human's job should be direction, design, and approach, not managing bugs.
The human's influence should be powerful over what gets built and should not determine whether it is built well.

The resolution proposed: desirability is the human's job, quality is the machine's.
Human authority belongs where the machine has no oracle, which is also where changing your mind is cheap.
This is consistent with the existing first principle that the spec is the truth about what the system should do.

## Measured Finding: Where the Cost Actually Is

The session store at `~/.claude/aiw-observation/sessions.jsonl` was read on 2026-08-31.
The store was last rebuilt on 2026-08-21, so it is ten days stale.
It held 189 sessions, 173 of them with more than 100,000 input-side tokens.

Aggregate input-side tokens were 9,223,674,796.
Cache reads were 9,035,388,120, which is 98.0% of input.
Cache creation was 188,127,979, which is 2.0%.
Uncached input was 158,697, which rounds to 0.0%.
Output was 40,458,531 tokens.
Total estimated cost was $19,670.

Per-session cache hit rate had a median of 95.9%, a tenth percentile of 83.2%, and a ninetieth percentile of 98.9%.
The external benchmark for a healthy harness is a median of 84% and a top tenth of at least 94%.
The worst tenth of these sessions is roughly the healthy median.

Cost concentrates in a few sessions.
The top 20 sessions accounted for 53% of spend and the top 50 accounted for 81%.
The largest single session cost $1,455 across 72 user turns and 889 tool calls, consuming 779 million input tokens.

The Agent tool was used in 30 of 172 costed sessions, which is 17%, with 208 Agent calls in total.

### What the finding rules out

Prompt caching is not a lever here.
There is no saving available from prefix hygiene, and time spent on it would be wasted.

### What the finding rules down

Cheaper models and other providers save on token price.
The measured problem is token volume in the main loop, not token price.
A free or cheaper model in a subagent saves the same volume as a Claude subagent does.
Multi-provider routing is therefore a secondary optimisation rather than the main one.

### What the finding rules in

The ratio of input-side to output tokens is 228 to 1.
Every tool call re-sends the whole conversation, so cost grows with the square of session length.
The 889th tool call in a session re-reads the results of the 888 calls before it.

This is a different argument for subagents than the one in the source material.
The saving does not come from a cheaper model.
It comes from work never entering the main prefix, so it is never re-read.
A subagent running the same model on the same work still saves money.

### The connection between the two topics

Removing gates makes sessions longer.
Cost grows with the square of session length.
The streamed factory therefore only works if Build and Test run outside the main context.
The two changes under discussion require each other.

## Gates and Streams

The difference between a gate and a stream is where the default sits.
A gate makes the human's silence a brake.
A stream makes the human's silence an accelerator.

Under gates, agent throughput is capped by human attention even when nothing is wrong.
Under a stream, attention is spent only when something is wrong, and only if the human can tell that it is.

What is given up is real and should not be understated.
Under a gate the human cannot fail to review, because nothing proceeds until they do.
Under a stream the human can fail to review by not looking, and the work proceeds anyway.
Gates convert attention into a hard guarantee and streams convert it into a probabilistic one.

For Build and Test specifically, the guarantee protects little that is permanent.
The work is on a branch, nothing external has happened, and everything is reversible.
The existing autonomy guidance places isolated branches with rollback available at medium to high autonomy once verification is mature.

The trade is therefore not risking a bad outcome to save human time.
It is risking wasted machine time to save human attention.
Machine time is the cheap input, so the trade is usually good.

### The catch

Wasted work is only cheap if the waste is discovered.
The dangerous case is the agent going wrong, producing work that passes every test, and the human approving it at PR because it arrives finished, coherent, and with a persuasive account of itself.
Roughly half of test-passing agent pull requests on SWE-bench Verified would not have been merged by maintainers.

### What the Build and Test gates actually catch

Five things, of which no test catches the first three.

Scope creep, where the agent built more than was asked and the tests still pass.
Technically implemented but semantically wrong, where the requirement is satisfied on a reading nobody intended.
Tests that prove the implementation rather than the requirement.
An approach that is wrong in a way only visible in code rather than in the plan.
Taste, meaning this is ugly and will be painful to work with later.

The first three are word for word the list given to the independent reviewer in fresh context in the harness-engineering source.
That is not a coincidence, because the independent reviewer is the mechanism designed to replace a human gate at those points.

The fourth is partly a Plan-gate failure and partly genuine.
The fifth is irreducibly human but can be deferred to PR, because ugly code does not stop being ugly while it waits.

So the five sort into three delegated to a refuting reviewer, one pushed up to Plan, and one deferred to PR.
None require the human to sit at Build.

### The condition

The Build and Test gates can be dropped once something else catches scope creep, semantic wrongness, and tests that prove the code rather than the requirement.
That something is a second agent, in fresh context, told to attack the work rather than run it.
This is the load-bearing piece of the design, not an optional addition.

## How the Three Catches Would Work

Scope creep is half mechanical.
The plan names the files and the diff names the files, so comparing them requires no judgment.
The judgment half is when the agent touched only the named files but did more inside them.

Semantic wrongness is pure judgment.
It needs a reader holding the requirement and not holding the implementer's reasoning.

Tests that prove the implementation have a real deterministic check in mutation testing.
Change the code and see whether a test fails.
If no test fails, the test is holding nothing.

### Three properties the reviewer must have

It attacks rather than assesses.
Asked whether the work is good, a reviewer says yes.
Asked to find where the work fails, it finds things.
The maintainer's own recorded result is that a refuting pass broke three of five pull requests a confirming pass had cleared.

It never sees the implementer's transcript.
The narrative is what makes a wrong reading sound right.

Its findings are evidence rather than orders.
Without this it becomes a second thing to rubber-stamp.

### What happens when it finds something

The work goes back once.
If a second pass does not clear it, that is the existing non-convergence signal, and that is when the human is interrupted.

### The brakes that already exist

The stream does not need new stopping conditions.
The non-convergence rule stops when attempts thrash.
The verification skill stops when the committed method cannot run.
The Ask First list stops on dependencies, schema changes, and deletions.
What is missing is only the default being set to proceed.

### Conditional gates

This is not all-or-nothing per stage.
The planning skill already flags higher-risk changes at plan time, including real seams, external systems, and data flow between processes.
Higher-risk work can keep its gates while routine work streams.

## Seeing the Build

A gate needs a summary and a yes or no.
An interruptible stream needs the human to see what is happening well enough to choose when to intervene.
Observability is therefore a precondition of the dark factory rather than a separate feature.

The maintainer's prior attempts at visual project representation failed on maintenance, because keeping diagrams in sync did not work.

### The split

High level should be durable and low level should be ephemeral.

### The durable half

Pure derivation gives structure, not architecture.
A generated dependency graph is accurate and unreadable, because it shows everything with no sense of what matters.
Meaning comes from intent, and intent must be authored.

The proposal is to author the intent, derive the picture, and show the disagreement.
The authored artifact is a small statement of what the layers are and what may depend on what.
Architecture should change rarely, so that statement does not have the sync problem.
The picture is generated from the code each time and coloured by whether it agrees with the intent.
Where reality matches intent it is quiet, and where it diverges it is loud.

This is close to machinery that already exists.
`project-context.md` has an Architecture Summary.
The planning skill already requires every plan to name, for each architectural boundary it touches, either the deterministic check that enforces it or its absence as an unverified surface.
The durable picture is the accumulated answer to a question the workflow already asks.
It would also turn the context-drift hook from an advisory nudge into a real sensor.

### The ephemeral half

An ephemeral picture has no sync problem, because it never persists to drift.
The design question is when it fires and at what altitude.

Requiring a picture is a forcing function for altitude.
Prose lets an agent avoid deciding what matters, because it can list everything.
A picture cannot, and twenty boxes is visibly bad in a way that twenty paragraphs is not.
The ephemeral diagram may fix the wall-of-text problem as a side effect.

### Altitude is not the same as format

The maintainer's complaint about walls of text after exploration is an altitude problem, not a format problem.
A diagram drawn at implementation altitude is as useless as prose at implementation altitude.
This needs fixing separately from adding diagrams.

## Conformity to Existing Structure

The agent's natural leaning is to use what exists even when it is messy, complex, or structurally wrong.
Three causes, needing different fixes.

The workflow instructs it.
The planning skill says that if the issue suggests a structure the codebase does not follow, plan against the real structure.
That rule exists because issues go stale, and its side effect is making the codebase normative rather than merely descriptive.

Every change is judged locally.
A change that fits the mess is locally correct, and nothing ever asks whether the mess should exist.
This is Tesler's law, where complexity is conserved and each local fit preserves it invisibly.

The agent has no stake in six months.
Structural debt is a cost that lands outside the horizon of the task being evaluated.

### Where the fix belongs

The mess is not the problem.
The mess being invisible at the moment of the decision that adds to it is the problem.

The workflow currently makes conforming the default and improving an interruption, through the rule to ask before changing documented architecture.
The proposed change is that at plan time, when the natural implementation would add to a known structural problem, the agent surfaces it as a choice.
This costs nothing when the answer is to fit in, and catches the case where the human wanted otherwise.

### New projects and old projects fail differently

On a new project the agent has nothing to conform to, so the risk is generic output.
On an old project the risk is accretion.
The north-star guards against generic and the structural check guards against accretion.

## Autonomous Loops

Two loop shapes were discussed.
An audit loop running audit, plan, issues, build, test, PR.
A log-driven loop running logs, plan, issues, build, test, PR.

The log-driven loop is the stronger of the two.
An audit returns many findings that are true and not urgent, shaped like the checker rather than like the pain.
That is the optimisation backlog the maintainer does not want.
Logs return real failures, which are self-prioritising because something actually broke.

The audit loop improves if it is narrowed from finding problems to three things sourced from observed pain.
Where changes keep landing.
Where structure has diverged from stated intent.
Where the agent conformed to something already flagged.

### The real constraint is rate

Any autonomous loop terminates at a PR, which is a gate, and everything before it is reversible.
The danger is not correctness but generating PRs faster than the human merges them.
That is the review queue the load-shedding rule warns about.
The control is a work-in-progress limit that stops new work starting while a set number of PRs sit unreviewed.

## North-Star and Briefs

The workflow has an oracle for correctness in the ground-truth trust hierarchy.
It has no oracle for taste.
The question "which of these two acceptable options do you want" has no answer other than asking the human, and that question is the source of most remaining interruptions.

This makes the north-star load-bearing in the streamed factory rather than decorative.
Every gate removed was removed by finding something else to answer its question.
The refuting reviewer handles correctness.
It cannot handle whether this should be a modal or a page, whether this should fail loudly or degrade, or whether a dependency is worth it.
The north-star is what answers those without the human.

### Altitude

A north-star statement should be about the product's character and still decide code-level questions.
If it is about code it is too low.
If it decides nothing it is too high.

An earlier example in the discussion, "never add a dependency to save fifty lines", was rejected by the maintainer as too low level.
It is a coding convention and belongs in project context or a lint rule.

The shape that does the most work is a preferred failure.
"Better to do nothing than the wrong thing" is about character, mentions no code, and decides whether to degrade or fail loudly, whether to auto-apply or ask, and whether to guess a format or reject it.

### Refusals decide, intentions do not

A north-star that says what the human wants is weaker than one that says what they would refuse.
"Fast and simple" answers nothing.
Most interruptions are a choice between two acceptable options, and only a refusal collapses that choice.

### Build it from corrections

An aspirational north-star is worse than none, because the agent follows it and produces something that does not fit the human.
Every time the human overrules the agent, that is a data point about their taste.
Corrections are the raw material, and they are evidence rather than imagination.

It is testable.
Take ten decisions the human actually made and check whether the north-star predicts them.
A north-star that cannot predict past calls will not predict future ones.
This test is what stops it becoming a mission statement.

### The brief is the ephemeral middle layer

A brief is the output of grilling.
It holds the preferences and refusals specific to one piece of work.
The north-star is too general to cover them and the issue is too concrete to hold them.

It should die with the work.
Persisting briefs would accumulate and drift, which is the diagram sync problem again.

When the same refusal appears in three briefs, it was never about those features.
That is a north-star entry.
The ephemeral layer feeds the durable layer when a pattern repeats, mirroring the decision made about diagrams.

## Escaping a Mess: A Missing Modality

Requirements change over time, and structure and architecture become the thing holding a project back.
The workflow has no route out of that.

Refactor preserves behaviour and changes structure.
Migrate preserves behaviour and substrate with an exception list.
Every one of the nine modalities treats current behaviour as at least part of the oracle.

In the case being described, requirements moved and current behaviour is the problem.
Refactor is actively the wrong tool because it preserves the thing being escaped.

The oracle for escaping is the north-star and the feature intent.
The maintainer identified this without naming it as an oracle.
This is a second reason the north-star is load-bearing: without it there is nothing to rebuild against except the mess being left.

### On the risk

Large restructures are not risky because they are large.
They are risky because the behavioural safety net is lost.
Full equivalence is not needed, only equivalence for the parts intended to be kept.
Separating behaviours being kept from behaviours that were the mess produces an exception list.
That is what Migrate modality already does, pointed at design instead of substrate.

## Measuring Project Health

The goal is a measure that changes with mess and does not change with project size or feature count.

Shape-of-code metrics are unsuitable.
Cyclomatic complexity, file length, and coupling scores are gameable.
Splitting a 400-line file into four 100-line files improves every metric while comprehension gets worse.
Complexity is conserved, so the metric moved and the complexity did not.

Measure the cost of change instead, as ratios and concentrations rather than counts.

Churn concentration, meaning what share of changes land in what share of files.
Cross-boundary co-change as a share of all changes, meaning how often a change has to touch more than one module.
Fix-after-fix rate, meaning what fraction of changes are followed by a corrective change.
Attempts per accepted change.

These are outcome measures rather than structure measures, which is why they are hard to game.
The only way to improve them is to make the area genuinely easier to change.
Splitting a file into four that always co-change makes the coupling signal stronger, not weaker.

Adding a feature cleanly touches one module, needs no correction, and takes one attempt, so none of the four ratios move.
Adding a feature messily touches four modules, needs two corrections, and takes three attempts, so all four move.
Project size and feature count cancel out.

### One honesty constraint

A metric that only improves is not measuring.
Sometimes a project should get more complex because it does more.
The honest claim is not that complexity falls but that complexity is paid for.
The measurable form is whether the cost of change in an area is rising while what the area does stays flat.

## The Non-Determinism Gap

The maintainer builds agent systems, which are non-deterministic.
The agent's natural leaning is deterministic software architecture, because that is what the training data holds and the agent field is new.
This repository is itself an agent project, being prose that steers a model.

### Why agent architecture is genuinely different

Composition degrades.
In deterministic software, a correct A composed with a correct B is correct.
In agent software, 90% composed with 90% is 81%.
Standard architecture has nothing to say about this because it never had to.

Shallow pipelines beat deep ones, because every stage multiplies error.
Deterministic software rewards decomposition and agent software punishes it past a point.

Every agent-to-agent boundary is a lossy contract, because it is natural language.
A thin brief returning confident wrong work is a property of the boundary rather than a briefing bug.

Verification is an architectural component rather than a development process.
Tests sit outside deterministic software.
In agent software the checks must run inside the system at runtime.

Work should be pushed out of the model wherever a deterministic component can do it.
Cross-calendar date accuracy moved from roughly 34% to roughly 95% by running code instead of reasoning.
This is an architectural principle that would never be stated for normal software.

Retry is not recovery but a re-roll.
A retried deterministic call is safe and a retried agent call produces a different answer.

### Where this workflow breaks on it

The verification skill requires, for Fix modality, a check that failed before the fix and passes after, and calls it non-negotiable.
On a stochastic path that is a coin flip presented as evidence.
If a defect occurs 5% of the time, one passing run proves nothing.

The evidence hierarchy has no rung for running something twenty times and passing nineteen.
That is the correct evidence for agent code and the hierarchy cannot express it.

The ground-truth trust hierarchy addresses where a fixture came from.
For agent projects the harder problem is that the expected output is a distribution with several acceptable answers.

This repository's own sensor is `scripts/check-prose-integrity.sh`, which states that it is structural and cannot tell whether two passages contradict each other.
The deterministic part is checked and the stochastic part, which is the actual product, is not.

## Open Questions

Whether Build and Test should proceed without human approval, in exchange for being interruptible.
Whether the refuting reviewer is built before, alongside, or after that change.
What the observability surface looks like in practice, given that an interruptible stream needs one.
Whether escaping a mess is a new modality or Migrate pointed at intent.
Whether the project health measures are computed from git history, from the session store, or both.
How the workflow's verification rules should change for non-deterministic systems.
Where the north-star lives, how it is authored, and how corrections feed it.

## Sources

The cost and cache figures are measured from the maintainer's own session store on 2026-08-31.
They are local to this developer's usage and are not generalisable.

The following claims come from an external personal knowledge base rather than from `design/research/`.
They are not yet recorded in this repository with anchor IDs, which is a gap.

Harness engineering, sensors, the independent reviewer, and the load-shedding rule come from `concept-harness-engineering`.
Delegation economics, the METR result, the attention bottleneck, and the autonomy-by-reversibility table come from `concept-delegation-economics`.
Model and effort as separate axes, and the capability versus thoroughness diagnosis, come from `concept-model-effort-routing` and `src-claude-code-model-and-effort`.
Cache figures, effort curves, the orchestrator and advisor boundaries, and cost per completed task come from `src-optimizing-for-cost-and-intelligence`.
Sub-agent routing and its failure modes come from `concept-subagent-cost-routing`.
Test-time compute, the calendar tool result, and the limits of more reasoning come from `concept-inference-compute-scaling`.
Tesler's law and Goodhart's law come from `concept-software-engineering-laws`.

The Anthropic measurements in those sources are vendor-run and described by their publisher as directional rather than guaranteed.
The METR trial is a real randomised result on early-2025 tooling and should not be generalised.
The practitioner frameworks in the delegation-economics source are untested.
