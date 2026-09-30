---
name: aiw-issue-creation
description: "Structured process for creating follow-up or spin-off GitHub issues during a task. Use this skill whenever the agent drafts an issue, including one the human asked for, and when it discovers work outside the current scope, names a surface unverified at aiw-verification's scoping step, or finds a recurring limitation aiw-init reports, and that work should be tracked. The skill exists to prevent implementation-heavy issues that bias the implementing agent and peg to stale code."
---

# Issue Creation

Read this file when drafting any GitHub issue.

## Before Creating the Issue

- Search open issues in the repository for overlap with the proposed issue's intent.
- If a potential overlap is found, surface the overlapping issue to the human before proceeding.
- Search the codebase for other sites where the same request would apply. A request arrives phrased for the place the human noticed it, which is not always the place it belongs.
- Only proceed with creation after the human confirms there is no duplicate.

## When the Request Fits More Than One Site

Settle the question by one search now, not by counting how often this request has come up before. Sites that share the shape today are visible in the current session; a count of past occurrences needs memory across sessions and arrives after the divergence it would have prevented.

Scope does not move. The issue stays at the site the human named, and the finding lands in the acceptance criteria rather than in a note, because a note is free to ignore and acceptance criteria are what the work is checked against. Bind the criterion to the requested site alone, and state it as a property of the result rather than a design to follow: adopting it at the other sites would not mean rewriting it. Name those sites by path.

Sorting is asked for on one list screen, and four list screens share the shape. The issue stays on that screen, and its acceptance says the other four could adopt the result unchanged. That is checkable on one screen's diff and commits nobody to touching the others.

Do not ask the human which unit to build. Record what you found and carry on; a question here spends the altitude the workflow exists to protect.

## Where These Issues Come From

Follow-up work discovered mid-task is one source. The other is aiw-verification's scoping step: a surface the work named as unchecked, which is not being checked now, is tracked here rather than left as prose. Such an issue names the surface and what would close it, and goes through the same human confirmation as any other — a gap the agent filed unasked is not a resolution. It does not prescribe the check — by the time someone picks it up, the right way to cover that surface may not be the way you would have done it today.

A limitation that keeps producing the same declared gap, which aiw-init's preflight reports when it recurs, arrives here as a third shape. That issue is not about the surface the current task left unchecked; it is about removing the limitation that keeps producing the gap. Name the limitation, list the earlier occurrences as evidence of its cost, and state what would end it. One such issue replaces the whole run of caveats — do not file one per occurrence.

## What the Issue Must Contain

- State what needs to change from the user's perspective.
- State why the change is needed and what triggered the discovery.
- State acceptance criteria if they are clear.

## What the Issue May Contain

- Reference a relevant file by path to locate the concern. A path locates; carrying the code into the issue pegs it. Do not reproduce what a file says or prescribe how to change it. Both peg the issue to today's implementation and bias whoever picks it up toward an approach that may not fit by then.
- Optionally, a short list of workflow skills that may help whoever implements it. Frame this as a hint to orient the implementing agent, not a mandate or a prescribed solution.

## Restrictions You Introduce

A limit on scope or reach that you add while drafting, what the work will not do or where it will not reach, and that the human did not state, is not written as a requirement. If `north-star.md` rules it out, drop it. Otherwise put it under an `## Agent-introduced limits` heading and to the human before work on the issue starts, and record their answer there. Keeping the issue at the site the human named, above, is their scope rather than a limit you introduce. (Why: the issue is filed under the human's name, so every later step reads an unmarked restriction as theirs.)

## Keeping Issues Concise

- Keep the issue short.
- State intent, not process.
- One issue per concern.
