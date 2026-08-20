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

1. **What could plausibly have broken as a result of this change.** Name the surfaces the change touches and the surfaces downstream of those.
2. **What evidence shows those things did not break.** Cite the specific checks run and what they actually observed.
3. **What was not checked, and why.** Either because it was out of scope, because it was impractical, or because the agent did not think of it until now.

This step is non-skippable. The output is short — a few lines is usually enough — but the act of producing it forces real thought about coverage. An agent that cannot answer part 1 has not understood the change. An agent that cannot answer part 2 has not verified it. An agent that pretends part 3 is empty is hiding risk.

If part 1 surfaces something part 2 does not cover, the change is not verified. Either run additional checks or move the gap explicitly into part 3 and acknowledge the risk to the user.

## What the Change Could Move

Part 1 fails most often on the word "downstream". Read as "the other code that calls this", it misses the surface that actually breaks: something computed from the value or shape the change moved, often on the same screen, often by a library or the rendering layer that nothing in the codebase appears to call.

Ask two questions, not one:

- **What reads this?** Every consumer of the value, shape, ordering, grouping, or type the change altered: the next pipeline stage, the cache, the serialiser, the query that assumed the old shape.
- **What is derived from this?** Every quantity computed from it that nobody wrote down: an axis scale, a total, a page count, a layout height, a sort order, a cache key.

Check what those two questions return, and stop there. Proportion is the point — the surfaces that consume what the change moved, not the whole system. One fix regrouped a chart's data, corrected the reported grouping, and pushed the highest values off the top of the plot, because the charting library recomputed the vertical scale from the new grouping. Nothing called that code. The grouping was its input.

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

If end-to-end execution is impractical for a specific change, name why in the justification step's part 3 and treat the unverified end-to-end path as a known risk.

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

Hiding unverified surface produces false confidence: the human reading the report assumes everything the agent did not mention was checked. Naming it produces calibrated confidence: the human knows what to look at, what to ask about, and where to direct manual verification if any is warranted.

If the unverified surface is large enough that the change cannot be trusted without more work, say so. Recommending additional verification is not weakness; it is the correct output.
