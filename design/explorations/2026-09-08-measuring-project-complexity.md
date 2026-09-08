# Measuring Project Complexity: Where a System Resists Verification

Explores how to measure a project's complexity and locate it, when complexity does not track size and much of the work is LLM-based or agentic.

## Status

This is an exploration, not a decision.
Nothing here has been implemented and no option has been chosen.
It records the output of a structured adversarial debate held on 2026-09-08, so the reasoning is not lost.

Everything in this document is argument.
Nothing in it is measured.
The instrument it describes has never been run against a real repository, and its calibration is intuition, not evidence.
That limitation is not a caveat at the end; it is the main thing to know about the document, and Validity below states why.

## The Question

How complex is a project, and where is the complexity?

The difficulty is that complexity does not track size.
A forty-thousand-line CRUD application can be easier to change safely than a four-hundred-line agent loop.
Every metric that measures the artifact's bulk gets this backwards, and most of the field's metrics measure bulk.

The second difficulty is that many of the projects in question have LLM or agentic components, where the classical frames were not designed to reach.

## Method

Four positions were argued in parallel by separate agents, each briefed to argue its side as strongly as it honestly could and forbidden to hedge toward the others.

- Structural: complexity is computable from the artifact.
- Cognitive: complexity is the cost of building a correct mental model, measurable only behaviourally.
- Non-determinism: agentic systems need their own axes.
- Sceptic: no metric survives, and the honest deliverable is a set of diagnostic questions.

All four were given the same seven calibration cases with stipulated rankings, and each was required to score itself against them and name its own failures before reporting.
This is known-groups validity: a measure is tested against cases where the answer is already agreed.

Three disagreements survived the first round and were cross-examined by further agents briefed to resolve rather than survey them.

The calibration cases were:

- A: a 40,000-line CRUD application, uniform patterns, deterministic, well tested. Stipulated LOW.
- B: a 400-line multi-agent LLM loop with tools, retries, and a shared scratchpad. Stipulated HIGH.
- C: three services with eventual consistency and no distributed transaction. Stipulated HIGH.
- D: a production compiler, large and deep, with a formal spec and a near-total test oracle. Stipulated MEDIUM-HIGH but tractable.
- E: a React application with mutable global state read and written by thirty components. Stipulated HIGH relative to size.
- F: a 2,000-line pure data-transformation library. Stipulated LOW.
- G: a repository of governance prose and shell hooks, small, where no automated check can tell whether two passages contradict each other. Stipulated unresolved.

A versus B is the discriminating pair.
Size fails it, and so does cyclomatic complexity.

## Finding 1: The Word "Complexity" Is Hiding Four Properties

The sceptic interrogated the calibration cases themselves and found the oracle unsound as a single ranking.

The seven verdicts do not rank one property.
A, D, and F are ranked on structural complexity: branching, state size, spec formality.
B, C, and E are ranked on emergent behaviour: shared mutable state plus non-determinism.
G is ranked on whether coherence can be checked at all.
D's "tractable" smuggles in a fifth idea, expected verification cost, which is not complexity at all.

The property that is consistent across all seven is **verification risk under available oracle strength**: how hard is it to tell whether this is wrong, and how far does a wrong thing travel before anyone finds out.

This is the reframe the rest of the document rests on.
It explains the A-versus-B inversion without special pleading.
The CRUD application is large and has a near-total oracle, so wrongness surfaces immediately and locally.
The agent loop is small and has almost no oracle, so wrongness surfaces late, far away, or never.

It also explains D.
A compiler is deep but not treacherous, because a formal spec and a near-total test oracle mean depth costs time rather than confidence.
Depth and treachery are different properties, and only one of them is what people mean when a project feels complex.

## Finding 2: The Answer Is a Profile, Not a Score

The historical record on complexity scalars is close to unbroken failure, and the failures share one mechanism.

Lines of code rewarded verbosity.
Cyclomatic complexity was gamed by extracting branches into helpers and replacing conditionals with dispatch tables, dropping the count while spreading the behaviour across more files.
Halstead measures were never validated against human comprehension.
The Maintainability Index combined several unvalidated metrics into one number, which launders invalidity through arithmetic rather than removing it.
Function points became a contract-negotiation lever.
Story points became a velocity KPI and detached from effort within a sprint or two.
Code coverage produced tests that execute lines without asserting behaviour.

The pattern is not Goodhart's law in the abstract.
It is that each metric was cheap to compute and expensive to fake at the moment it was designed, and became cheap to fake the moment an incentive attached to it.

Two systems can also be genuinely incomparable, and forcing them onto one axis destroys information rather than creating it.
Case B and case G are the worked example, and Finding 3 covers why.

So the instrument is an unaggregated profile.
Rows are axes, each answered Low, Medium, or High with concrete located evidence.
Nothing is summed.
There is no single number, so there is nothing to target.

## Finding 3: Severity and Reducibility Are Different Questions

The sceptic's sharpest objection was that scoring case B and case G both HIGH is actively harmful, because it prescribes the wrong remedy to both.
The agent loop's difficulty yields to engineering: schemas, bounded retries, checks closer to the source.
The prose corpus's difficulty does not, and "write more tests" there is not merely insufficient but a category error.

The cross-examination accepted the distinction and rejected the name.

"Irreducible" is a claim about the universe and cannot be settled, because almost everything is reducible in principle and remedy selection ranges over available options rather than possible ones.
The defensible claim is about the cheapest calibratable oracle available today.
The label is therefore **judgement-bearing**, and it is contradictable.

Three remedy classes fall out, not two.

- Build the check. The pass condition can be written as a sentence a machine evaluates.
- Change the shape. No check exists for the current design, but a different design would admit one.
- Buy standing attention. No calibratable check is available, so a human reads this on a cadence, forever.

The middle class is the one people skip and where most of the value sits.

The test for classifying a surface takes under a minute.

1. Can you state the pass condition without the words appropriate, consistent, means the same, reads well, or in the spirit of? If yes, this is not judgement-bearing. It is a check you have not built yet.
2. If you propose an automated judge, what would you hold its verdicts against? Without a labelled set of known-bad cases, the judge does not reduce the burden; it relocates it, and you now review the reviewer at the same rate. Call this **oracle regress**.
3. Could a change of shape make question 1 answerable?

Case G is the worked example of question 3, and the sceptic's own calibration was too quick.
"Do these two paragraphs contradict each other" has no parser.
But enforcing that a rule is stated in exactly one place collapses cross-paragraph entailment into a uniqueness check a shell script can run.
`ai-workflow.md` already states the principle, that one rule kept in several places is several copies of the same defect.
That line is a complexity remedy, not a style preference.
What remains judgement-bearing after the redesign move is much smaller than the whole corpus, and that gap is the difference between a classification and an excuse.

Reducibility is recorded as a second column on each row rated Medium or High, not as its own axis.
It is a property of a surface-and-failure-mode pair rather than of a surface, so a standalone axis would force an average across facts that differ.
A standalone axis would also be summable, and therefore something a person could be asked to reduce this quarter.

**The guard against the lazy label.** Marking a surface judgement-bearing does not close it.
It converts it into a standing review commitment with a named person and a stated cadence.
That inverts the incentive: building a check is a one-off cost you can defer, while judgement-bearing costs attention every cycle forever.
If nobody will fund the ritual, the label was false and what actually happened was silent risk acceptance.
The label also carries a date and the named check that was considered and rejected, with the rejection reason, because that reason is usually the price list for reducing it later.

## Finding 4: What Is Genuinely Different About LLM and Agentic Systems

The position hired to argue that agentic systems are special conceded that its axes were not LLM-specific.
Decision delegation ratio is determinism.
Oracle cost per behaviour class is oracle strength.
Tool surface reach and propagation depth before first check are blast radius.
Context accumulation is state enumerability.

That collapse is a real result rather than a defeat, and it is good news: it means one general instrument, on which agentic systems simply score high on everything.

The final cross-examination tested whether the concession went too far, and found that it did, in a narrow band.
The test applied was not whether the general instrument can reach a high score, but whether an axis has an **input the general instrument cannot take**.

Three properties pass that test.

**Contract-free substrate exposure.**
That a model is a dependency you cannot inspect, version, or diff is not distinctive; that is true of any closed SaaS dependency, and blast radius at maximum scores it correctly.
What is distinctive is that every other such dependency carries a behavioural contract, which defines what counts as a regression and bounds the region that could have moved.
A model provider promises a name and a token limit.
Nothing about behaviour is promised, so nothing is a violation, so the set of behaviours that may have moved is the whole set.
The consequence is that **the measurement expires with no observable event**.
Every conventional complexity measure assumes stationarity between commits: a score is valid until something visible changes.
Here behaviour moves while the artifact, the git history, and every static score sit still.
That is a different input domain, not a higher value on an existing axis.

**Specification self-interference.**
As "prose has no composition rules" this is just coupling with worse tooling, and feature-flag combinatorics have produced individually-correct-jointly-broken systems for decades.
The property that survives is stronger: a prose specification competes with itself for a finite adherence budget.
Adding a correct instruction can reduce compliance with an unrelated correct instruction already present.
No code system has this, because adding a module does not make an existing module less likely to execute its written semantics.
Underneath sits a structural oddity worth naming: in an LLM system the prompt is simultaneously the specification and the implementation, so the spec-versus-implementation comparison that the whole verification apparatus rests on is unavailable by identity rather than by cost.

**Change-to-comprehension ratio.**
All four opening positions measured a system at a moment, assessed by an engineer with unbounded time.
None measured flux against comprehension.
In an agentic workflow the artifact is edited at machine speed by something that does not need to understand it afterwards, while the human accountable for it builds their model at human speed.
A project can score acceptably on every static axis and still be out of control, because change is landing faster than anyone can track it.
This is complexity as a derivative rather than as a noun, and it was the blind spot the shared framing produced.

Two candidates were rejected.

Statistical rather than binary correctness is not new; error budgets, containment, and blast-radius limiting are the mature response, and propagation depth before first check already measures it.
One caveat adjusts how that axis is used rather than adding one: LLM errors are neither stationary nor independent across retries, so the redundancy arithmetic error-budget reasoning assumes does not hold, and retrying often reproduces the error class.

Reflexivity, that the measurer and the measured are the same kind of thing, buys nothing epistemically; compilers compile compilers.
The residue is a resource fact rather than a paradox and is covered by specification self-interference.

## Finding 5: An Agent-Authored Profile Fails Differently

This matters because a profile in this repository would be read, and probably written, by an agent.

The sceptic's defence against gaming rested on three legs: no principal-agent gap because it is self-administered, no scalar to target, and answered by argument rather than formula.
Legs two and three hold.
Leg one collapses, but not into a principal-agent problem.

An LLM has no durable stake across sessions, so it will not run a gaming campaign.
What it does instead is generate the assessment from the same model, the same priors, and the same context that generated the artifact being assessed.
The errors do not cancel.
The profile then carries no information the codebase did not already carry, wrapped in prose that reads like independent evidence.
Call this a **closed loop**, and note that it is the same failure `aiw-ground-truth` exists to break when the agent writes the code, the fixtures, and the tests.

It is compounded by **verification asymmetry**: a confident paragraph costs the agent seconds and costs the human an hour to check.

Three failure modes arrive with no adversary at all, which makes them harder to notice than gaming and easier to test for.
They are harder because every defence built for gaming looks for divergence under pressure and there is no pressure, and because they are correlated across every axis and every update rather than averaging out.
They are easier because each leaves a signature that deliberate gaming is designed not to leave, and each is testable by perturbation.

- Sycophancy correlates with the requester's framing. Keep the expected answer out of the authoring context, then re-author with the framing inverted; if ratings move, the profile is measuring the prompt.
- Anchoring correlates with the prior document. Withhold the anchor rather than instructing against it, author fresh against the code, then diff and require every changed axis to be explained.
- Base-rate regression correlates with genericness. Strip the citations; if the remaining sentence could be pasted into any other project, that axis is describing software in general.

The common structure is to remove the contaminating input and then test by perturbing it, which is differential testing applied to prose.

Two proposed defences were rejected on inspection.

Recording the disconfirming evidence the agent looked for and did not find is exactly as cheap to fabricate as the positive claim and strictly harder to check, because absence claims leave no artifact.
Narrowed, it works: name the specific search that would have falsified the rating as something re-runnable, and its result.

Replacing ratings with questions was rejected because a question commits to nothing, so nothing can be wrong and nothing can be audited.
Unfalsifiability is the disease, not the cure, and it pushes the analysis back onto the human, which inverts the north-star.

The minimal set that survives:

- A re-checkable citation on every rating: a file, a line, a named state cell, a specific behaviour with no oracle. This does not make ratings correct; it makes them falsifiable, which is the only property that survives an author you cannot audit. An axis that cannot produce a citation has told you something real about itself.
- Pinning to a commit SHA, with drift computed over the cited paths, the way `validation.status` binds a pass to a tree fingerprint and `check-context-drift.sh` counts commits behind HEAD. Mechanical staleness rather than remembered staleness.
- Authoring in a clean context by an agent that did not do the implementation. This does not remove model-level correlation, but it removes context correlation, which is most of the practical damage.
- **Outcome collision.** Every rating is a prediction. A Low oracle-strength rating predicts that changes in that area produce surprises. When `aiw-failure-analysis` fires on a contradicted done claim, check what the profile said about that area. This is the only proposal that makes the profile accountable to something other than its own prose, and it needs no new machinery.

## The Instrument

Not a score. A profile, per surface, unaggregated.

Six general axes:

1. **State enumerability.** Can you list the places that mutate shared state, and roughly enumerate the reachable states?
2. **Determinism.** Same input, same output and same trace? Can a failure be replayed?
3. **Oracle strength.** Does a machine-runnable spec, invariant, or property check exist, and how close to total is it?
4. **Cross-component agreement.** When two parts disagree about the world, is there a protocol that reconciles them, or does disagreement propagate silently?
5. **Blast radius.** If you change this, is the set of things you must re-verify bounded and computable?
6. **Explainability.** Could you explain a failure from the artifact alone, or did you need to be present when it happened?

Three axes for LLM and agentic systems:

7. **Contract-free substrate exposure.** What fraction of behaviours pass through a component whose provider promises no behavioural invariant, and how long since those behaviours were last measured? This is the axis whose score moves while the artifact is byte-identical.
8. **Specification self-interference.** How much prose behaviour-specification is in force at once, and has adherence to each instruction been measured with the full corpus loaded rather than alone?
9. **Change-to-comprehension ratio.** Is behaviour-relevant change landing faster than the accountable human can build a correct model of it? Project-level rather than per-surface.

The sceptic's seventh axis, mechanizability of review, is not an axis here.
It became the reducibility column, because it is the question that selects the remedy rather than one that describes the surface.

Each row rated Medium or High carries: the rating, a re-checkable citation, and a reducibility class of build the check, change the shape, or judgement-bearing.

The profile is pinned to a commit SHA, and drift is computed over the cited paths.

**Where the complexity is** falls out of the citations rather than needing a separate mechanism.
A profile whose High ratings all cite the same three files has located itself.

## What Is Weak Here

**The instrument is unvalidated.**
It was calibrated against seven cases whose rankings one person stipulated from intuition.
Reproducing those rankings is evidence that a scheme was fitted to that intuition on hand-picked, cleanly separated examples, not evidence of a general property.
This is the same failure as a benchmark authored by whoever grades it.
Real validation is outcome collision accumulated over time, and that takes months.

**Surface selection is unsolved.**
The profile is per surface, and nothing here says how surfaces are chosen.
Modules are the wrong unit, because the failures being measured cross module boundaries.
Trust and oracle boundaries are the likely right unit, and that is a hypothesis rather than a finding.
This is the largest hole in the design.

**Nine axes may not survive contact with an hour.**
The sceptic budgeted an hour for seven axes, self-administered.
Nine axes plus a reducibility column plus a citation per row is more than that, and an instrument nobody completes is worse than a crude one they do.

**Axis 9 is not complexity.**
It is throughput against comprehension, and admitting it risks letting "complexity" mean everything.
It is kept because omitting the variable that most reliably precedes losing control would make the instrument answer a question adjacent to the one asked.

**The behavioural signals have no cold start.**
Time to first correct change, backtrack rate, and false-done rate are the strongest signals available, and none of them exists on day one.
At time zero the structural and oracle axes are all there is, and they answer how much can go wrong here regardless of who wrote it, rather than how much has gone wrong.

## Where This Repository Stands, If The Instrument Is Right

Stated as hypothesis, not measurement, since the instrument has not been run.

Axis 8 appears to be at or near its ceiling.
`ai-workflow.md` plus fifteen skills is a large prose specification read in force, and `scripts/check-prose-integrity.sh` is documented as structural only, unable to tell whether two passages contradict each other.
That is axis 8, unmeasured, already written down as a known gap.

Axis 7 has no coverage at all.
Nothing in this repository re-runs on a model change, and no CI in existence fires on someone else's deploy.

Axis 9 is what the north-star bets on.
The human at the altitude of taste while the AI works beneath them is a standing wager that comprehension keeps up with change.

The observation tooling under `observation/` already sits on the data that would produce the strongest behavioural signal, false-done rate, which is the fraction of done claims later contradicted.
It does not currently compute it.

## Open Questions

- How are surfaces chosen? This blocks use more than anything else here.
- Does the instrument fit in an hour, and if not, which axes earn their place?
- Should the profile live in the agent-read set at all? The argued position is that it belongs in the class of `field-notes/investigations/` rather than the class of `project-context.md`: pulled on demand at planning time, never auto-loaded, because a file read before every task functions as a premise and a premise the agent authored about its own work is self-certification. The condition attached is firm: build the drift check and outcome collision with the profile, or keep it out of the agent-read set entirely, because a profile without them is a guess laundered into a premise.
- Is false-done rate worth computing in `observation/` independently of this instrument? It is the sharpest single signal the debate produced and the only one this repository could already measure.
