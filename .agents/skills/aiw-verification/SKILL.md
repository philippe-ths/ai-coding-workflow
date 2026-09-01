---
name: aiw-verification
description: "Governs how the agent confirms a change actually works before declaring a task complete. Use this skill at the end of every implementation pass and whenever the agent is about to say 'done', 'this works', 'tests pass', 'ready to commit', or 'ready to push'. Also use when interpreting runtime output, deciding whether to run the full system end-to-end, claiming a refactor preserves behaviour, a fix is fixed, a migration is complete, or a delete is safe. It forces the agent to justify every time that its checks cover the change and to name the unverified surface, breaking the 'all tests pass, system is broken' failure mode. It owns the required justification step before declaring done, the evidence hierarchy from static checks to end-to-end runs on real artifacts, the rules for when end-to-end execution is mandatory, reading runtime output as evidence not exit codes, modality-aware requirements referencing aiw-ground-truth, and the scoping step that names what was not checked."
---

# Verification

Read this file before declaring any task complete, before claiming "this works", before moving toward commit, push, or pull request, and whenever the agent is about to interpret tool output as success.

## Why This Skill Exists

A passing test suite is not evidence the system works. It is evidence that the tests the agent chose to run passed, against the fixtures the agent chose to use, in the way the agent chose to interpret the output. Each of those choices is a place where the verification can be locally valid and globally wrong.

The failure mode this skill exists to prevent: every check passes, the agent declares done, and the change breaks the system on first real use. The cause is almost always coverage — the checks did not actually exercise the path the change affected — rather than test correctness. The remedy is not more tests by default. It is forcing the agent to argue, explicitly and every time, that the checks it ran are sufficient evidence the change works.

Classify the task using the modality decision procedure defined in aiw-ground-truth. Verification requirements depend on the modality.

## The Justification Step

Before declaring any task complete, produce a short, explicit argument with three parts:

1. **What could plausibly have broken as a result of this change.** Name what reads the value, shape, ordering, grouping, or type you altered, and what is derived from it that nobody wrote down — an axis scale, a total, a cache key. Downstream is not only the code that calls yours.
2. **What evidence shows those things did not break.** Cite the specific checks run and what they actually observed.
3. **What was not checked, and why.** Either because it was out of scope, because it was impractical, or because the agent did not think of it until now.

This step is non-skippable. The output is short — a few lines is usually enough — but the act of producing it forces real thought about coverage. An agent that cannot answer part 1 has not understood the change. An agent that cannot answer part 2 has not verified it. An agent that pretends part 3 is empty is hiding risk. A change genuinely can have nothing unverified, but an empty part 3 is an argument in terms of what the change is — "this changes no runtime path, so there is nothing to exercise" — never the bare assertion "nothing".

If part 1 surfaces something part 2 does not cover, the change is not verified. Either run additional checks or move the gap explicitly into part 3 and acknowledge the risk to the user.

Part 1 is bounded by those two questions: check what they return and stop there, the surfaces that consume what the change moved rather than the whole system. One fix regrouped a chart's data, corrected the reported grouping, and pushed the highest values off the top of the plot, because the charting library recomputed the vertical scale from the new grouping. Nothing called that code. The grouping was its input.

## Evidence Hierarchy

Verification evidence ranges from weak to strong. Stronger forms do not eliminate the need for the justification step; they only make it easier to satisfy.

Weakest to strongest:

1. **Static checks pass.** Type checking, linting, syntax. Evidence of ambient quality only. Says nothing about behaviour.
2. **Unit tests pass.** Weak-to-moderate. Only as good as the fixtures backing them; if the fixtures are synthetic (see aiw-ground-truth's trust hierarchy), the evidence is weak regardless of how green the bar is.
3. **Integration tests pass.** Moderate. Catches problems at seams between components inside the system, provided the seams are exercised in a realistic configuration.
4. **End-to-end run on synthetic input.** Moderate. Exercises the full path but proves only that the system handles the agent's idea of input.
5. **End-to-end run on real ground-truth artifact.** Strong. Exercises the full path against an input the real system would actually encounter.
6. **Diff against captured previous behaviour matches the expected change set.** Strong for refactor and migrate. Confirms that what should not have changed has not changed, and what should have changed has changed in the expected way.

These levels are not interchangeable. Strong evidence (5 or 6) is required for changes touching real seams between components, real interfaces with external tools or libraries, or any path where component composition is itself the thing being tested.

When citing evidence in the justification step, name the level, not just the name of the check. "Unit tests passed against synthetic fixtures" is honest; "tests passed" hides which level was actually achieved.

## When End-to-End Execution Is Mandatory

Run the full system end-to-end, on real ground-truth artifacts where the modality requires them, in at least these cases:

- Any change to data flowing between processes or services.
- Any change to a stage of a pipeline.
- Any change to an interface with an external tool or library.
- Any refactor or migration claiming behaviour preservation.
- Any delete operation.

End-to-end execution is cheap for an agent. Humans optimise testing practice to avoid the cost of standing up the full system, restarting services, or waiting for slow runs. The agent does not pay those costs the same way and should not inherit human shortcuts. When in doubt, run the whole thing. (Why: the cost of a missed regression dwarfs the cost of one more end-to-end run.)

Drive that end-to-end run with a fresh sub-agent, one that did not write the change and carries none of its context, and have it report what it observed. You are the worst verifier of your own change: you exercise what you expected to build and read the output through the same assumptions that shaped the code, the self-referential loop aiw-ground-truth exists to break, reappearing at verification time. A clean-context agent reaches the surface a real user would. Weigh its report in the main loop as evidence, not a verdict.

If end-to-end execution is disproportionate to the change, name why in the justification step's part 3 and treat the unverified path as a known risk. A method that is not disproportionate but simply cannot run is the next section, not this one.

## The Refuting Pass

The end-to-end run above sends a clean-context agent to observe what the system does.
Nobody has yet been asked to find where the work fails.
A reviewer asked whether work is good says yes.
A reviewer asked to find where work fails finds things.
Ask the second question before presenting work for the human's done decision.

Drive it with a sub-agent that did not write the change.
It is not the end-to-end runner: that one observes behaviour, this one reads what the change claims against what was asked for and tries to break the claim.

### What it is given, and what is withheld

Give it the requirement, meaning the issue plus the plan's scope and file list, the diff, and the evidence part 2 cites.

Withhold the implementer's transcript, reasoning, and narrative.
The narrative is what makes a wrong reading sound right.
A reviewer that has read why the code was written this way will accept that it is written this way.

### What it is asked to find

Ask it to find failures, not to assess quality.
Name the three it is hunting:

- Work that satisfies the words of the requirement and not its intent.
- Change beyond what the plan named: files the plan did not list, and work inside listed files that the plan did not call for.
- Tests that would still pass if the code under them were wrong.

The second is half mechanical, because the plan names files and the diff names files.
The third has a deterministic form wherever the tooling exists: change the code and see whether a test fails.
Prefer it, and where it does not exist ask the reviewer to name, for each test, the breakage that test would catch.

### What its findings are worth

Findings are evidence weighed in the main loop, never a verdict to act on unread.
A reviewer that must be obeyed becomes a second thing to rubber-stamp.
A reviewer that can be dismissed in silence is not a check at all.
Every finding ends in one of the four states the scoping step below requires: checked, tracked, waived, or deferred.

### When it does not clear

Work goes back once.
A second pass that does not clear the same finding is an approach repeated without new evidence, which is the non-convergence rule in ai-workflow.md.
Stop implementation, invoke aiw-failure-analysis, and tell the human that a refuting finding is what stopped the work.
Do not try a third variation.

### When it cannot be skipped

It cannot be skipped for any change that alters what the system does.
Instruction files that direct an agent are what such a system does, so prose is not exempt by being prose.
A change that alters no behaviour of any kind skips this the way part 3 can be empty: by an argument in terms of what the change is, never by bare assertion.
If the sub-agent it needs is unavailable, that is the next section, not this one.

## When the Committed Method Cannot Run

The plan named the evidence this task would produce. Sometimes that method is not available when the time comes: sub-agents are unavailable in this session, the API key is unfunded.

Substituting a weaker method and disclosing it honestly is not the honest option it appears to be. The disclosure is real; the decision is still the agent's, and it is not the agent's to make. Accepting weaker evidence changes what the done claim is worth, and what it is worth is the human's call. aiw-ground-truth already forbids silently substituting a lower trust level for an *input*; the same rule applies to *evidence*.

Stop and put it to the human in the Asking for Guidance format, with these options:

- **Accept the weaker evidence**, with the reduced worth of the claim stated plainly rather than buried.
- **Wait** until the committed method is available.
- **Narrow the claim** to what the available evidence does support, and leave the rest unverified and named.

Recommend one, then wait.

"Sub-agents were unavailable, so the end-to-end evidence is self-verified" is a decision reported as a circumstance. Nothing about the sentence is false, and the human still never got to make the choice.

## Reading Runtime Output

Exit code 0 is not success. A script that produced no output, produced the wrong output, or silently skipped its real work can exit cleanly. Verification requires active inspection:

- **Compare produced artifacts to expected ones.** If the change is supposed to produce output X, confirm output X exists and is shaped correctly. Do not assume from absence of error.
- **Scan logs for warnings and errors.** Warnings the agent did not expect are signals. Errors that the program recovered from are still errors.
- **Check that the work the change was supposed to do actually appears in the output.** If the change adds a transformation, the output should show that transformation. If the change is a fix, the previously failing case should now succeed in the output, not merely not throw.
- **Notice silence.** A run that completes faster than expected, produces fewer outputs than expected, or skips a code path that should have executed is a verification failure, not a verification pass.
- **Name where a reading came from.** Evidence taken from a running system — a config value, a live setting, a stored row, a log line — is a reading from one process in one environment, and the code under test may not run there. State which process or environment you read it from, and confirm that is where the code executes, before the reading counts as evidence. (See aiw-ground-truth: real is not the same as relevant.)
- **When the runtime path lacks output to read, add observability.** For changes touching writes, sync, state transitions, integration points, or reactive UI paths, automated tests often cannot prove the path executed as expected. If that is the case, add observability — temporary or permanent — to the change as part of the implementation, so this section has something concrete to inspect.

Structurally-correct-but-semantically-wrong outputs are the failure mode this catches. The shape of the output looks right; the content is wrong. Only active inspection finds these.

## Modality-Aware Verification

The modality for this task has already been classified — typically during planning via aiw-planning, or directly via aiw-ground-truth for tasks started without a planning step. This section applies the verification requirements for the already-classified modality; it does not re-classify. For compound tasks, apply the union of all relevant requirements.

- **New.** Confirmed examples produce the expected outputs. Explicitly name in the justification that real-usage exposure has not happened — first contact with reality is still ahead.
- **Feature.** Two checks: the new behaviour works on confirmed examples, and the existing behaviour the feature touches has not changed. A green run on the new path alone is insufficient.
- **Fix.** A check that failed before the fix and passes after is non-negotiable. Without it, there is no evidence the fix addresses the reported bug. Adjacent inputs that were working continue to work, and so does whatever is derived from what the fix changed — a fix verified against its own symptom alone is where the second defect comes from. The justification must also name the coverage gap that allowed the bug to ship — what kind of check would have caught it earlier.
- **Refactor.** Strict behavioural equivalence on real inputs. A before/after comparison is required: either captured outputs match, or the same end-to-end run produces the same observable behaviour. Equivalence claimed without comparison is not verified.
- **Improve.** For any behavioural aspect, apply the refactor rule. For non-behavioural aspects (naming, readability, simplification), state explicitly that the verification rests on human judgement rather than mechanical checks. Do not claim verification for non-behavioural changes.
- **Investigate.** A specific claim about cause backed by specific evidence, not a list of hypotheses. A reliable reproducer is the strongest verification; if one cannot be produced, state what is missing to produce one.
- **Migrate.** End-to-end comparison on real inputs from the old substrate against the new. The exception list from aiw-ground-truth — behaviours intentionally not preserved — is documented and individually accounted for. A completeness sweep confirms no remaining uses of the old substrate that should have been migrated.
- **Configure.** The real external system is exercised at least once. A green test against a mock is not verification in this modality; it confirms only that the mock matches the agent's model of the external system.
- **Delete.** A dependency search across the whole codebase, including dynamic references (strings, reflection, plugin registries, config files, generated code), confirms nothing still relies on what was removed. The search also reaches outside the repository, to state the removed code installed elsewhere: scheduled jobs, global or user-level config, registered hooks, files under `$HOME`, installed services. Deleting code does not unregister what it registered, and nothing in the repository can report it, so the leftover keeps firing against a path that no longer exists. The justification names what was removed, the evidence that nothing depended on it, and either how the outside state was accounted for or that the subsystem installed none. Do not assume a clean build means no dependencies remain — runtime references compile.

## The Scoping Step

The justification's part 3 is the scoping step. Use it deliberately.

For any non-trivial change, name the unverified surface as risk, not as absence. "I did not check X" is honest but incomplete. "I did not check X, which means a regression in [specific failure mode] would not be caught by what I ran" is calibrated.

If the unverified surface is large enough that the change cannot be trusted without more work, say so. Recommending additional verification is not weakness; it is the correct output.

### Every Named Surface Gets a Resolution

Naming the surface is half the step. The other half is what became of it, settled before the work is presented for the human's done decision. Each item in part 3 ends in one of four states, and a state is reached when its artifact exists, not when its word is written:

- **Checked.** You closed the gap during this task. The artifact is what you ran and what it showed; the item then belongs in part 2.
- **Tracked.** An issue carries it, and the artifact is the issue number. Proposing that issue is yours; creating it is the human's, under aiw-issue-creation.
- **Waived.** The human accepted the gap. The artifact is their words, and what they were told when they said them. You cannot waive on their behalf, and silence is not a waiver.
- **Deferred.** The method has not run yet and you can say when it will, before the human decides. The artifact is the method named, that timing, and the reason for the wait: "the clean-context end-to-end pass, once quota resets in an hour". Deferred is the one state that does not close an item, because its artifact is a commitment rather than a result. Posting the result where the work is presented is what closes it, as Checked, in front of the person deciding. This is the Wait option kept visible rather than finished work held back, and two limits keep it that way. The evidence your modality requires cannot be deferred: a fix with no check that failed before and passes after, or a refactor with no before-and-after comparison, is not ready to present whatever else has run. And if you cannot say when it runs, or it turns out it will not, it is not deferred but "When the Committed Method Cannot Run", where the choice is the human's.

Name the gap by its cause rather than by the task. "No real external-model call — the API key is unfunded" can be recognised the next time it appears; "could not fully test the coach for #712" cannot, and a gap nobody can find is a gap that gets declared fresh forever.

A label with no artifact behind it is not a resolution. (Why: it is the same undisclosed gap in a tidier format, and a column of correct-looking labels hides that better than plain prose did.)
