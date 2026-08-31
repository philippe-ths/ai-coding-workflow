---
name: aiw-north-star
description: "Structured process for authoring and updating `north-star.md`, the shortest statement of what a project is trying to achieve. Use this skill when the human asks to create, scaffold, revise, or check the north-star, with phrasings like 'what is this project for', 'set up a north-star', or 'is that still the goal'. Use it also, and without being asked, when a request that has just arrived would take the project away from its stated goal, before any planning happens: that conflict means either the request is wrong or the goal has moved, and neither is the agent's call. The skill exists because a project's direction is the one thing no oracle can derive: the codebase shows what is, the spec shows what is asked, and neither says what the project is trying to achieve."
---

# North Star

Read this file before creating or editing `north-star.md`, and when a request pulls against what it says.

## Why This Skill Exists

The workflow knows what the system does, because the codebase says so. It knows what the system should do, because the spec says so. Nothing says what the project is trying to achieve, so every judgement turning on the project's direction is resolved by interrupting the human.

## What Goes In

The goal, and nothing else.

Short is the point rather than a courtesy. This is read at the start of every task, so anything in it that does not change a decision is taken from the work. A goal that has grown into a list of everything the project does has stopped being a goal.

The human is its source of truth. The agent writes the file, the same division `project-context.md` uses with the codebase, except the codebase cannot supply this one.

## Altitude

Too low and it describes what the project currently does. Such a goal was read out of the codebase and can never judge it, because the codebase is what it would be judging.

Too high and nothing could ever conflict with it. A goal no request could contradict decides nothing and is worth no space.

The test: could a plausible feature request pull against this? If nothing could, come down until something could.

## Authoring: Interview, Confirm, Write

Never write this from inference alone. The goal is why the codebase looks as it does, so reading it back out of the artifact is circular.

1. **Prepare.** Read what exists and form a candidate goal. Bringing a candidate is the one part of this the agent can genuinely do; starting the human from a blank page wastes it.
2. **Interview.** Ask what the project is trying to achieve, one question at a time. Ask for the outcome, never for a summary, because a summary of a project is its description and this is not that.
3. **Confirm.** State the goal back in plain terms and get explicit agreement. A goal the human has not affirmed is the agent's guess wearing their authority.
4. **Write.** Shortest form that still holds what they said.

## When a Request Conflicts

A request that pulls the project away from its goal is a signal, not an obstacle. One of two things is wrong and the agent can determine neither.

Act on it when the request arrives, before planning. Planning around a conflict resolves it silently in favour of the request, and by the time a plan exists the conflict has been designed away.

- **Stop.** Name the goal and say specifically how the request pulls against it.
- **Ask.** The request may be wrong, or the goal may have moved.
- **Update, or proceed.** If the goal moved, interview and confirm before the work starts. If the request was wrong, the human says so and the file stands.

Never widen the goal to accommodate the request in front of you. A goal stretched to admit whatever conflicted with it will not conflict with anything again.

## Updating

The goal changes rarely, and when it does it is because the project became something else. That is worth recording plainly rather than smoothing over.

## Anti-Patterns

- **The description.** It restates what the project currently does, so it can never judge what the project does.
- **The mission statement.** Nobody could disagree with it and no request could contradict it.
- **The feature list.** The goal accreted clauses until everything the project does is in it and nothing is ruled out.
- **The silent resolution.** A conflicting request gets planned, and the conflict surfaces at review, or never.
- **Inferred and unconfirmed.** The agent wrote a plausible goal, the human never affirmed it, and it now decides on their behalf.
