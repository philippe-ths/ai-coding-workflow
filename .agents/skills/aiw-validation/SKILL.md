---
name: aiw-validation
description: "Governs whether the finished work is the thing the human asked for, as distinct from whether the change is correct. Use this skill at the done gate alongside aiw-verification and aiw-housekeeping, before presenting any work for the human's done decision, and whenever about to say 'done', hand over a deliverable, or open a pull request. It owns the deliverable the plan must name, the questions asked of finished work (does it exist, does it do what was asked, is it the thing the project is for), the requirement to meet the artifact in the form the human will meet it rather than read the code that produces it, the one line it leaves in the pull request body, and the split between what the human judges and what the agent confirms."
---

# Validation

Read this file before presenting work for the human's done decision, alongside aiw-verification and aiw-housekeeping.

## Why This Skill Exists

Verification asks whether the change is correct. Validation asks whether the result is the thing that was wanted. The two fail independently, and work can pass every check in a repository while delivering nothing the human asked for.

A request arrives in the human's words. It becomes an issue, then a plan, then a diff, and every gate downstream checks the work against the nearest translation. The human's own words are read once, at the start, and never again. The translations lose in one direction: toward what is convenient to check.

## The Deliverable

The deliverable is what the human will open, read, run, or look at when this is done. Not the code that produces it, not the tests that cover it, not the pull request that carries it.

Name it in the plan, as a noun, in the human's terms. "The threads page shows applications per week as a chart" is a deliverable. "Add charting to the threads view" is the work, and naming the work instead is how the thing goes missing: the work can be complete while the artifact is absent.

If the task produces nothing a human meets, say so in the plan. That sentence discharges this skill, and it is an argument about what the change is, never a bare assertion.

## The Questions

At the done gate, before the work is presented:

1. **Does it exist?** Go and find it. Committed code that would produce it is not it existing, and a passing test asserting it exists is not it existing.
2. **Does it do what was asked?** Re-read the human's own words, not the issue. Where the two differ, the words are the request and the issue is a summary that lost something. This question is about the artifact: is the thing there, doing the job it was asked to do. Whether the implementation satisfies the requirement's intent belongs to aiw-verification's refuting pass, which is already provisioned and uses a reviewer who did not write the change.
3. **Is it the thing the project is for?** Re-read `north-star.md` against what is about to be handed over. Task Flow step 1 already checked the request against the goal, so this catches only what drifted between the request and the result, which is its own class: a request can be granted exactly and the result still pull away from the goal.

## Meet It Where the Human Meets It

Open the artifact in the form the human will. A page gets rendered and looked at. A report gets read. A command gets run and its output read. A generated file gets opened. Where the deliverable is a library, a schema, or an endpoint, the human meets it through whatever consumes it, so run the consumer.

Reading the code that produces the artifact is not meeting it.

Do this yourself rather than sending an agent. aiw-verification sends a clean-context agent to run the system because you are the worst judge of whether your own change is correct: you read the output through the assumptions that produced it. That loop bites on judgements. It does not bite on absence. A report that was never written is missing for its author too, and no assumption rescues it.

## What It Costs

Resource Discipline scales a required step to the change. That governs how hard you look, not whether you look, and here the depth is one look: a one-line change to a dashboard earns a glance at the dashboard, not a test plan for it. The floor holds because the size of a change predicts nothing about whether the artifact still renders.

The cost is set by the deliverable, not the diff. Where meeting the artifact is genuinely expensive — a build that takes twenty minutes, a device you have to pick up — that expense is the thing to report, and the next section is where it goes.

## When the Deliverable Cannot Be Met

A device you do not have, a build you cannot run, an account you cannot reach. This is not a pass and not a deadlock. Take one of the four resolutions in aiw-verification's scoping step: checked, tracked by an issue, deferred with the method and its timing named, or waived by the human. Name the obstacle by its cause rather than by the task, so the same obstacle is recognisable the next time it appears.

## What It Leaves Behind

One line in the pull request body, beside the verification justification: the deliverable, and how it was met. "The weekly report, rendered for the week of 3 March and read against the SQL count." That sentence is the whole record.

It goes there for the reason the verification justification goes there: the human decides afterwards, and a check that leaves nothing behind cannot be told apart from a check that was skipped.

Say nothing about it in chat when the answers are yes. A no is different: it is a stop, not a caveat attached to the handoff. Fix it, or where the gap is that the request itself is ambiguous, stop and ask. Work that is not the thing asked for is not ready for a done decision, and handing it over with the gap disclosed moves the work to the human rather than resolving it.

## What Belongs to the Human

The human judges whether the result is good: whether it looks right, reads well, and feels right to use. That judgement needs their eyes and this skill does not take it from them.

The question underneath it is not theirs. Whether the thing is there and does what was asked is not taste, and it does not need a human. A human who opens the deliverable to find it missing, empty, or broken has been handed the agent's remaining work in the shape of a judgement call.
