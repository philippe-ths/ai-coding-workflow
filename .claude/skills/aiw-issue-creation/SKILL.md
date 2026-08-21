---
name: aiw-issue-creation
description: "Structured process for creating follow-up or spin-off GitHub issues during a task. Use this skill when the agent discovers work outside the current scope that should be tracked. The skill exists to prevent implementation-heavy issues that bias the implementing agent and peg to stale code."
---

# Issue Creation

Read this file when creating a follow-up or spin-off GitHub issue.

## Before Creating the Issue

- Search open issues in the repository for overlap with the proposed issue's intent.
- If a potential overlap is found, surface the overlapping issue to the human before proceeding.
- Only proceed with creation after the human confirms there is no duplicate.

## Where These Issues Come From

Follow-up work discovered mid-task is one source. The other is aiw-verification's scoping step: a surface the work named as unchecked, which is not being checked now, is tracked here rather than left as prose. Such an issue names the surface and what would close it, and goes through the same human confirmation as any other — a gap the agent filed unasked is not a resolution. It does not prescribe the check — by the time someone picks it up, the right way to cover that surface may not be the way you would have done it today.

A gap that has been declared repeatedly arrives here as a third shape. That issue is not about the surface the current task left unchecked; it is about removing the limitation that keeps producing the gap. Name the limitation, list the earlier occurrences as evidence of its cost, and state what would end it. One such issue replaces the whole run of caveats — do not file one per occurrence.

## What the Issue Must Contain

- State what needs to change from the user's perspective.
- State why the change is needed and what triggered the discovery.
- State acceptance criteria if they are clear.

## What the Issue May Contain

- Reference a relevant file by path to locate the concern. A path locates; carrying the code into the issue pegs it. Do not reproduce what a file says or prescribe how to change it. Both peg the issue to today's implementation and bias whoever picks it up toward an approach that may not fit by then.
- Optionally, a short list of workflow skills that may help whoever implements it. Frame this as a hint to orient the implementing agent, not a mandate or a prescribed solution.

## Keeping Issues Concise

- Keep the issue short.
- State intent, not process.
- One issue per concern.
